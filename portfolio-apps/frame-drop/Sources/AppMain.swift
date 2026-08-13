import PhotosUI
import SwiftUI

@main
struct FrameDropApp: App {
    @StateObject private var subscription = SubscriptionManager(monthlyID: "jp.egawa.framedrop.pro.monthly", yearlyID: "jp.egawa.framedrop.pro.yearly")
    var body: some Scene { WindowGroup { FrameDropView().environmentObject(subscription) } }
}

@MainActor
final class FrameStore: ObservableObject {
    @Published var images: [UIImage] = []
    @Published var index = 0
    @Published var kept = 0
    @Published var released = 0
    @Published var note = ""
    @Published var quotaNotice: String?
    @Published private(set) var decisions: [String: String] = [:]
    private let key = "jp.egawa.framedrop.decisions"
    private let indexKey = "jp.egawa.framedrop.index"
    private let freeNamespace = "jp.egawa.framedrop"
    let freeMonthlyLimit = 30
    private var directory: URL { let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrameDrop", isDirectory: true); try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
    init() {
        decisions = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?.sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        images = urls.compactMap { UIImage(contentsOfFile: $0.path) }
        index = min(UserDefaults.standard.integer(forKey: indexKey), images.count)
    }
    var current: UIImage? { images.indices.contains(index) ? images[index] : nil }
    var progress: Double { images.isEmpty ? 0 : Double(index) / Double(images.count) }
    var freePhotosRemaining: Int { FreeUsageQuota.remaining(namespace: freeNamespace, limit: freeMonthlyLimit) }
    func selectionLimit(requested: Int, isPro: Bool) -> Int {
        guard !isPro else { return requested }
        let count = min(requested, freePhotosRemaining)
        if count < requested { quotaNotice = "The free plan can select \(count) more photos this month. Pro is unlimited." }
        return count
    }
    func consumeAllowance(forLoadedPhotoCount count: Int, isPro: Bool) {
        guard !isPro else { return }
        for _ in 0..<min(count, freePhotosRemaining) { _ = FreeUsageQuota.consume(namespace: freeNamespace, limit: freeMonthlyLimit) }
    }
    func load(_ newImages: [UIImage]) {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (offset, image) in newImages.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.9) { try? data.write(to: directory.appendingPathComponent(String(format: "%04d.jpg", offset))) }
        }
        images = newImages; index = 0; kept = 0; released = 0; decisions = [:]; UserDefaults.standard.removeObject(forKey: key); UserDefaults.standard.set(0, forKey: indexKey)
    }
    func decide(_ action: String) { guard images.indices.contains(index) else { return }; decisions["\(index)"] = action + (note.isEmpty ? "" : ": \(note)"); note = ""; if action == "Keep" { kept += 1 } else { released += 1 }; index += 1; UserDefaults.standard.set(decisions, forKey: key); UserDefaults.standard.set(index, forKey: indexKey) }
    func restart() { index = 0; kept = 0; released = 0; UserDefaults.standard.set(0, forKey: indexKey) }
}

struct FrameDropView: View {
    @StateObject private var store = FrameStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var picks: [PhotosPickerItem] = []
    @State private var showPaywall = false
    var body: some View { NavigationStack { VStack(spacing: 18) {
        VStack(alignment: .leading, spacing: 6) { Text("Choose which photos matter.").font(.system(.title2, design: .rounded, weight: .bold)); Text(store.images.isEmpty ? "Select photos to review them one at a time." : "Reviewing \(store.index) of \(store.images.count)") .foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
        PhotosPicker(selection: $picks, maxSelectionCount: 100, matching: .images) { Label(store.images.isEmpty ? "Choose photos" : "Choose different photos", systemImage: "photo.stack") }.buttonStyle(.bordered).onChange(of: picks) { _, selected in Task { let allowed = store.selectionLimit(requested: selected.count, isPro: subscription.isPro); var loaded: [UIImage] = []; for item in selected.prefix(allowed) { if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { loaded.append(image) } }; store.consumeAllowance(forLoadedPhotoCount: loaded.count, isPro: subscription.isPro); store.load(loaded) } }
        if !subscription.isPro { Text("Free plan: \(store.freePhotosRemaining)/\(store.freeMonthlyLimit) photos left this month").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
        if let image = store.current { VStack(spacing: 14) { ProgressView(value: store.progress).tint(.purple); Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 380).clipShape(RoundedRectangle(cornerRadius: 24)); TextField("Why keep it? (optional)", text: $store.note).textFieldStyle(.roundedBorder); HStack { Button { store.decide("Release") } label: { Label("Release", systemImage: "trash") }.buttonStyle(.bordered).tint(.red); Button { store.decide("Keep") } label: { Label("Keep", systemImage: "heart.fill") }.buttonStyle(.borderedProminent).tint(.purple) } } } else if !store.images.isEmpty { VStack(spacing: 12) { Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(.green); Text("Review complete").font(.title3.bold()); Text("Keep \(store.kept) · Release \(store.released)\nUse Photos to make any final deletion.").multilineTextAlignment(.center).foregroundStyle(.secondary); Button("Review again") { store.restart() }.buttonStyle(.bordered) } .frame(maxHeight: .infinity) } else { Spacer() }
        if !subscription.isPro { Button("Unlock unlimited photo review with Pro") { showPaywall = true } }
    }.padding(20).background(Color(uiColor: .systemGroupedBackground)).navigationTitle("FrameDrop").sheet(isPresented: $showPaywall) { SubscriptionPaywall(name: "FrameDrop", benefits: ["Unlimited photo review", "Resume a stack later", "Organize entirely on your device"], privacyURL: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/portfolio/privacy.html")!) }.alert("Free plan", isPresented: Binding(get: { store.quotaNotice != nil }, set: { if !$0 { store.quotaNotice = nil } })) { Button("OK", role: .cancel) {} } message: { Text(store.quotaNotice ?? "") } } }
}
