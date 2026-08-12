import ARKit
import AVFoundation
import CoreMotion
import SwiftUI

struct ContentView: View {
    @StateObject private var store = MeasurementStore()
    @State private var selectedTab: AppTab

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        _selectedTab = State(initialValue: AppTab(rawValue: arguments.value(after: "-caliqoTab") ?? "home") ?? .home)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView().tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }.tag(AppTab.home)
            NavigationStack { ARMeasureView() }.tabItem { Label("AR Measure", systemImage: "viewfinder") }.tag(AppTab.measure)
            NavigationStack { LevelView() }.tabItem { Label("Level", systemImage: "circle.lefthalf.filled") }.tag(AppTab.level)
            NavigationStack { RulerView() }.tabItem { Label("Ruler", systemImage: "ruler") }.tag(AppTab.ruler)
            HistoryView().tabItem { Label("History", systemImage: "tray.full.fill") }.tag(AppTab.history)
        }.tint(Theme.cyan).environmentObject(store)
    }
}

private enum AppTab: String { case home, measure, level, ruler, history }
private extension Array where Element == String {
    func value(after argument: String) -> String? {
        guard let index = firstIndex(of: argument), indices.contains(index + 1) else { return nil }
        return self[index + 1]
    }
}

private enum Theme { static let navy = Color(red: 0.035, green: 0.07, blue: 0.13); static let cyan = Color(red: 0, green: 0.78, blue: 0.95); static let mint = Color(red: 0.34, green: 0.90, blue: 0.72) }

private struct HomeView: View {
    @EnvironmentObject private var store: MeasurementStore
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 10) { Text("Caliqo").font(.largeTitle.bold()); Text("Precision, whenever you need it.").font(.title3.weight(.medium)).foregroundStyle(.white.opacity(0.8)); Label("Private by design. Stored on this iPhone.", systemImage: "lock.fill").font(.footnote.weight(.medium)).foregroundStyle(Theme.mint) }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(LinearGradient(colors: [Theme.navy, Color(red: 0.04, green: 0.22, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        Text("Tools").font(.headline)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { NavigationLink { ARMeasureView() } label: { ToolCard(icon: "viewfinder", title: "AR Measure", detail: "Distance and area") }; NavigationLink { LevelView() } label: { ToolCard(icon: "circle.lefthalf.filled", title: "Level", detail: "Check alignment") }; NavigationLink { RulerView() } label: { ToolCard(icon: "ruler", title: "Ruler", detail: "Small objects") }; NavigationLink { FloorPlanView() } label: { ToolCard(icon: "square.split.2x2", title: "Room note", detail: "Area estimate") } }
        if let item = store.items.first { Text("Latest measurement").font(.headline); MeasurementRow(item: item) }
        Text("AR measurements can include error. Verify important dimensions with a physical measuring tool.").font(.footnote).foregroundStyle(.secondary)
    }.padding(20) }.navigationBarTitleDisplayMode(.inline) } }
}

private struct ToolCard: View { let icon: String; let title: String; let detail: String; var body: some View { VStack(alignment: .leading, spacing: 14) { Image(systemName: icon).font(.title2.weight(.semibold)).foregroundStyle(Theme.cyan); Spacer(); Text(title).font(.headline).foregroundStyle(.primary); Text(detail).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, minHeight: 126, alignment: .leading).padding(16).background(.background, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary)) } }

private enum ARMode: String, CaseIterable, Identifiable { case distance = "Distance", area = "Area"; var id: String { rawValue } }
private enum UnitSystem: String, CaseIterable, Identifiable { case metric = "Metric", imperial = "Imperial"; var id: String { rawValue } }
private struct ARResult { let meters: Double; let isArea: Bool; var text: String { isArea ? Units.area(meters) : Units.length(meters) } }

private struct ARMeasureView: View {
    @EnvironmentObject private var store: MeasurementStore; @State private var mode: ARMode = .distance; @State private var result: ARResult?; @State private var reset = UUID(); @State private var saving = false; @State private var cameraAccessBlocked = false; @AppStorage("caliqo.unitSystem") private var unitSystem = UnitSystem.metric.rawValue
    var body: some View { ZStack(alignment: .bottom) {
        if ARWorldTrackingConfiguration.isSupported {
            ARCameraView(mode: mode, reset: reset) { result = $0 }.ignoresSafeArea()
        } else {
            ContentUnavailableView("AR is unavailable", systemImage: "arkit", description: Text("AR Measure requires an ARKit-capable iPhone. You can still use the Level, Ruler, and Room note tools."))
        }
        VStack(spacing: 12) { HStack { VStack(alignment: .leading) { Text("AR Measure").font(.headline); Text(result == nil ? "Move slowly to find a surface" : "Measurement ready to save").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { result = nil; reset = UUID() } label: { Image(systemName: "arrow.counterclockwise").padding(10).background(.thinMaterial, in: Circle()) }.accessibilityLabel("Reset measurement") }; Picker("Mode", selection: $mode) { ForEach(ARMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented); Picker("Units", selection: $unitSystem) { ForEach(UnitSystem.allCases) { Text($0.rawValue).tag($0.rawValue) } }.pickerStyle(.segmented); if let result { HStack { Text(Units.format(result.meters, isArea: result.isArea, system: UnitSystem(rawValue: unitSystem) ?? .metric)).font(.system(size: 34, weight: .bold, design: .rounded)); Spacer(); Button("Save") { saving = true }.buttonStyle(.borderedProminent).tint(Theme.cyan) } } else { Text(mode == .distance ? "Tap a start point, then an end point." : "Tap three or more points to calculate area.").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading) } }.padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26)).padding()
    }.navigationTitle("AR Measure").navigationBarTitleDisplayMode(.inline).onAppear { let status = AVCaptureDevice.authorizationStatus(for: .video); cameraAccessBlocked = status == .denied || status == .restricted }.onChange(of: mode) { _, _ in result = nil; reset = UUID() }.sheet(isPresented: $saving) { SaveSheet(result: result, kind: mode == .distance ? .distance : .area) { store.add($0); saving = false } }.alert("Camera access needed", isPresented: $cameraAccessBlocked) { Button("OK", role: .cancel) {} } message: { Text("Allow camera access in Settings to measure with AR.") } }
}

private struct ARCameraView: UIViewRepresentable {
    let mode: ARMode; let reset: UUID; let completion: (ARResult?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIView(context: Context) -> ARSCNView { let view = ARSCNView(); view.scene = SCNScene(); view.automaticallyUpdatesLighting = true; view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))); context.coordinator.view = view; context.coordinator.mode = mode; let configuration = ARWorldTrackingConfiguration(); configuration.planeDetection = [.horizontal, .vertical]; view.session.run(configuration); return view }
    func updateUIView(_ view: ARSCNView, context: Context) { context.coordinator.mode = mode; if context.coordinator.lastReset != reset { context.coordinator.lastReset = reset; context.coordinator.clear(); completion(nil) } }
    final class Coordinator: NSObject { weak var view: ARSCNView?; var mode: ARMode = .distance; var lastReset = UUID(); var points: [SIMD3<Float>] = []; var nodes: [SCNNode] = []; let completion: (ARResult?) -> Void
        init(completion: @escaping (ARResult?) -> Void) { self.completion = completion }
        func clear() { nodes.forEach { $0.removeFromParentNode() }; nodes.removeAll(); points.removeAll() }
        @objc func tap(_ recognizer: UITapGestureRecognizer) { guard let view else { return }; guard let query = view.raycastQuery(from: recognizer.location(in: view), allowing: .estimatedPlane, alignment: .any), let hit = view.session.raycast(query).first else { return }; if mode == .distance && points.count == 2 { clear(); completion(nil) }; let p = SIMD3<Float>(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z); points.append(p); dot(p); if points.count > 1 { line(points[points.count - 2], p) }; if mode == .distance && points.count == 2 { completion(ARResult(meters: Double(simd_distance(points[0], points[1])), isArea: false)) }; if mode == .area && points.count > 2 { completion(ARResult(meters: Double(area(points)), isArea: true)) } }
        func dot(_ p: SIMD3<Float>) { let sphere = SCNNode(geometry: SCNSphere(radius: 0.012)); sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.systemTeal; sphere.simdPosition = p; view?.scene.rootNode.addChildNode(sphere); nodes.append(sphere) }
        func line(_ a: SIMD3<Float>, _ b: SIMD3<Float>) { let distance = simd_distance(a, b); guard distance > 0.001 else { return }; let cylinder = SCNCylinder(radius: 0.004, height: CGFloat(distance)); cylinder.firstMaterial?.diffuse.contents = UIColor.white; let node = SCNNode(geometry: cylinder); node.simdPosition = (a + b) / 2; node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(b - a)); view?.scene.rootNode.addChildNode(node); nodes.append(node) }
        func area(_ points: [SIMD3<Float>]) -> Float { let origin = points[0]; var sum: Float = 0; for index in 1..<(points.count - 1) { sum += simd_length(simd_cross(points[index] - origin, points[index + 1] - origin)) / 2 }; return sum }
    }
}

private final class LevelMotion: ObservableObject { @Published var roll = 0.0; @Published var pitch = 0.0; private let motion = CMMotionManager(); var degrees: Double { hypot(roll, pitch) * 180 / .pi }; func start() { guard motion.isDeviceMotionAvailable else { return }; motion.deviceMotionUpdateInterval = 1.0 / 30; motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in self?.roll = data?.attitude.roll ?? 0; self?.pitch = data?.attitude.pitch ?? 0 } }; func stop() { motion.stopDeviceMotionUpdates() } }
private struct LevelView: View { @StateObject private var motion = LevelMotion(); var body: some View { VStack(spacing: 28) { Spacer(); ZStack { Circle().stroke(.quaternary, lineWidth: 18).frame(width: 250, height: 250); Circle().fill(motion.degrees < 1 ? Theme.mint : Theme.cyan).frame(width: 58, height: 58).offset(x: motion.roll * 100, y: -motion.pitch * 100); Circle().stroke(.white.opacity(0.8), lineWidth: 2).frame(width: 64, height: 64) }; Text(String(format: "%.1f degrees", motion.degrees)).font(.system(size: 44, weight: .bold, design: .rounded)); Text(motion.degrees < 1 ? "Level" : "Adjust slowly").font(.headline).foregroundStyle(motion.degrees < 1 ? Theme.mint : .secondary); Spacer(); Text("Place the iPhone on a flat surface.").font(.footnote).foregroundStyle(.secondary) }.padding().navigationTitle("Level").onAppear { motion.start() }.onDisappear { motion.stop() } } }
private struct RulerView: View {
    @AppStorage("caliqo.pointsPerCentimeter") private var pointsPerCentimeter = 60.0
    @State private var offset: CGFloat = 0
    @State private var showCalibration = false

    var body: some View {
        VStack(spacing: 20) {
            HStack { Text("Screen ruler").font(.headline); Spacer(); Button("Calibrate") { showCalibration = true } }
            GeometryReader { _ in
                Canvas { context, size in
                    let minorStep = CGFloat(pointsPerCentimeter / 10)
                    let center = size.width / 2 + offset
                    let start = Int(floor((-center) / minorStep)) - 1
                    let end = Int(ceil((size.width - center) / minorStep)) + 1
                    for index in start...end {
                        let x = center + CGFloat(index) * minorStep
                        let major = index.isMultiple(of: 10)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: major ? 74 : 40))
                        context.stroke(path, with: .color(.primary), lineWidth: major ? 2 : 1)
                        if major { context.draw(Text("\(index / 10) cm").font(.caption), at: CGPoint(x: x + 7, y: 92), anchor: .leading) }
                    }
                    let centerPath = Path(CGRect(x: size.width / 2 - 1, y: 0, width: 2, height: size.height))
                    context.fill(centerPath, with: .color(Theme.cyan))
                }
                .gesture(DragGesture().onChanged { offset = $0.translation.width })
            }
            .frame(height: 150)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
            Text("Place a small object on the screen and align its edge with the cyan marker. Calibrate once for your device before use.").font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
        .padding().navigationTitle("Ruler")
        .sheet(isPresented: $showCalibration) { ScreenCalibration(pointsPerCentimeter: $pointsPerCentimeter) }
    }
}

private struct ScreenCalibration: View {
    @Binding var pointsPerCentimeter: Double
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Match the two cyan guides to the short edge of a standard bank card (85.60 mm), then save.").font(.body)
                GeometryReader { proxy in
                    let width = min(proxy.size.width - 40, CGFloat(pointsPerCentimeter * 8.56))
                    ZStack { RoundedRectangle(cornerRadius: 12).stroke(Theme.cyan, lineWidth: 3).frame(width: width, height: 130); Text("CARD").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }.frame(height: 180)
                Slider(value: $pointsPerCentimeter, in: 35...90, step: 0.1)
                Text(String(format: "%.1f points per cm", pointsPerCentimeter)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
            }
            .padding().navigationTitle("Calibrate ruler")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct FloorPlanView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var width = 3.6
    @State private var depth = 4.2
    @State private var saved = false

    var body: some View {
        Form {
            Section("Room dimensions") {
                Stepper("Width: \(Units.length(width))", value: $width, in: 0.5...30, step: 0.1)
                Stepper("Depth: \(Units.length(depth))", value: $depth, in: 0.5...30, step: 0.1)
            }
            Section("Estimate") {
                LabeledContent("Floor area", value: Units.area(width * depth))
                LabeledContent("Perimeter", value: Units.length(2 * (width + depth)))
                Button(saved ? "Saved" : "Save room estimate") { store.add(Measurement(id: UUID(), name: "Room estimate", value: width * depth, kind: .area, date: .now, note: "\(Units.length(width)) x \(Units.length(depth))")); saved = true }
                    .disabled(saved)
            }
            Section { Text("Use AR Measure for each wall, then enter the values here for a quick planning estimate.").font(.footnote) }
        }.navigationTitle("Room note")
    }
}
private enum MeasurementKind: String, Codable { case distance, area }
private struct Measurement: Identifiable, Codable { let id: UUID; let name: String; let value: Double; let kind: MeasurementKind; let date: Date; let note: String }
private final class MeasurementStore: ObservableObject {
    @Published private(set) var items: [Measurement] = [] { didSet { UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: "caliqo.measurements") } }
    init() { if let data = UserDefaults.standard.data(forKey: "caliqo.measurements"), let loaded = try? JSONDecoder().decode([Measurement].self, from: data) { items = loaded } }
    func add(_ item: Measurement) { let cleanedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines); items.insert(Measurement(id: item.id, name: cleanedName.isEmpty ? "Untitled measurement" : cleanedName, value: item.value, kind: item.kind, date: item.date, note: item.note), at: 0) }
    func update(_ item: Measurement, name: String, note: String) { guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }; let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines); items[index] = Measurement(id: item.id, name: cleanedName.isEmpty ? "Untitled measurement" : cleanedName, value: item.value, kind: item.kind, date: item.date, note: note) }
    func remove(_ offsets: IndexSet) { items.remove(atOffsets: offsets) }
    func remove(_ item: Measurement) { items.removeAll { $0.id == item.id } }
}
private struct SaveSheet: View { let result: ARResult?; let kind: MeasurementKind; let save: (Measurement) -> Void; @Environment(\.dismiss) private var dismiss; @State private var name = "New measurement"; @State private var note = ""; var body: some View { NavigationStack { Form { Section("Value") { Text(result?.text ?? "-").font(.title2.bold()) }; Section("Details") { TextField("Name", text: $name); TextField("Note", text: $note, axis: .vertical) } }.navigationTitle("Save measurement").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if let result { save(Measurement(id: UUID(), name: name, value: result.meters, kind: kind, date: .now, note: note)) } } } } } }
}

private struct HistoryView: View { @EnvironmentObject private var store: MeasurementStore; @AppStorage("caliqo.unitSystem") private var unitSystem = UnitSystem.metric.rawValue; var body: some View { NavigationStack { List { if store.items.isEmpty { ContentUnavailableView("No measurements", systemImage: "tray", description: Text("Save an AR measurement to find it here.")) } else { ForEach(store.items) { item in NavigationLink { MeasurementDetailView(item: item, unitSystem: UnitSystem(rawValue: unitSystem) ?? .metric) } label: { MeasurementRow(item: item, unitSystem: UnitSystem(rawValue: unitSystem) ?? .metric) } }.onDelete(perform: store.remove) } }.navigationTitle("History").toolbar { EditButton() } } } }
private struct MeasurementRow: View { let item: Measurement; var unitSystem = UnitSystem.metric; var body: some View { HStack(spacing: 14) { Image(systemName: item.kind == .distance ? "arrow.left.and.right" : "square.dashed").foregroundStyle(Theme.cyan).frame(width: 26); VStack(alignment: .leading, spacing: 3) { Text(item.name).font(.headline); Text(item.date, style: .date).font(.caption).foregroundStyle(.secondary); if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary).lineLimit(1) } }; Spacer(); Text(Units.format(item.value, isArea: item.kind == .area, system: unitSystem)).font(.subheadline.bold()) } } }

private struct MeasurementDetailView: View { let item: Measurement; let unitSystem: UnitSystem; @EnvironmentObject private var store: MeasurementStore; @Environment(\.dismiss) private var dismiss; @State private var name = ""; @State private var note = ""; @State private var isEditing = false; @State private var showingDelete = false; var body: some View { Form { Section("Measurement") { LabeledContent("Type", value: item.kind == .area ? "Area" : "Distance"); LabeledContent("Value", value: Units.format(item.value, isArea: item.kind == .area, system: unitSystem)); LabeledContent("Saved", value: item.date.formatted(date: .abbreviated, time: .shortened)) }; Section("Notes") { if isEditing { TextField("Name", text: $name); TextField("Note", text: $note, axis: .vertical).lineLimit(3...6) } else { Text(item.name); Text(item.note.isEmpty ? "No note" : item.note).foregroundStyle(item.note.isEmpty ? .secondary : .primary) } }; Section { ShareLink(item: item.shareText) { Label("Share measurement", systemImage: "square.and.arrow.up") } } }.navigationTitle(item.name).toolbar { ToolbarItem(placement: .primaryAction) { Button(isEditing ? "Save" : "Edit") { if isEditing { store.update(item, name: name, note: note); dismiss() } else { isEditing = true } } }; ToolbarItem(placement: .bottomBar) { Button("Delete", role: .destructive) { showingDelete = true } } }.onAppear { name = item.name; note = item.note }.confirmationDialog("Delete this measurement?", isPresented: $showingDelete, titleVisibility: .visible) { Button("Delete", role: .destructive) { store.remove(item); dismiss() } } } }
private extension Measurement { var shareText: String { "\(name): \(kind == .area ? Units.area(value) : Units.length(value))\(note.isEmpty ? "" : " — \(note)")" } }
private enum Units { static func length(_ meters: Double) -> String { meters >= 1 ? String(format: "%.2f m", meters) : String(format: "%.1f cm", meters * 100) }; static func area(_ meters: Double) -> String { String(format: "%.2f m²", meters) }; static func format(_ value: Double, isArea: Bool, system: UnitSystem) -> String { guard system == .imperial else { return isArea ? area(value) : length(value) }; return isArea ? String(format: "%.1f sq ft", value * 10.7639) : String(format: "%.2f ft", value * 3.28084) } }
