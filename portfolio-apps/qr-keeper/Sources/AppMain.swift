import AVFoundation
import SwiftUI

@main
struct QRKeeperApp: App {
    @StateObject private var subscription = SubscriptionManager(monthlyID: "jp.egawa.qrkeeper.pro.monthly", yearlyID: "jp.egawa.qrkeeper.pro.yearly")
    var body: some Scene { WindowGroup { QRHomeView().environmentObject(subscription) } }
}

@MainActor
final class QRStore: ObservableObject {
    struct SavedCode: Identifiable, Codable { let id: UUID; let value: String; let label: String; let expiresAt: Date?; let createdAt: Date }
    @Published private(set) var codes: [SavedCode] = []
    @Published var scannedValue = ""
    @Published var label = ""
    @Published var hasExpiry = false
    @Published var expiry = Date.now
    private let key = "jp.egawa.qrkeeper.codes"
    init() { codes = (try? JSONDecoder().decode([SavedCode].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? [] }
    func save() { guard !scannedValue.isEmpty else { return }; codes.insert(SavedCode(id: UUID(), value: scannedValue, label: label.isEmpty ? "名称未設定" : label, expiresAt: hasExpiry ? expiry : nil, createdAt: .now), at: 0); scannedValue = ""; label = ""; hasExpiry = false; persist() }
    func delete(_ offsets: IndexSet) { codes.remove(atOffsets: offsets); persist() }
    private func persist() { if let data = try? JSONEncoder().encode(codes) { UserDefaults.standard.set(data, forKey: key) } }
}

struct QRHomeView: View {
    @StateObject private var store = QRStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showScanner = false
    @State private var showPaywall = false
    var body: some View { NavigationStack { List {
        Section { VStack(alignment: .leading, spacing: 8) { Label("QRを、あとで迷わず使う。", systemImage: "qrcode").font(.system(.title3, design: .rounded, weight: .bold)); Text("読み取ったQRに用途と期限を付けて、端末内に控えます。リンクは勝手に開きません。").font(.subheadline).foregroundStyle(.secondary); Button { showScanner = true } label: { Label("QRを読み取る", systemImage: "camera.viewfinder").frame(maxWidth: .infinity).padding(8) }.buttonStyle(.borderedProminent) } }
        if !store.scannedValue.isEmpty { Section("読み取り結果") { Text(store.scannedValue).lineLimit(3).textSelection(.enabled); TextField("用途・場所（例: ジムの入館）", text: $store.label); Toggle("期限を設定する", isOn: $store.hasExpiry); if store.hasExpiry { DatePicker("期限", selection: $store.expiry, displayedComponents: .date) }; Button("控えに保存") { store.save() }.buttonStyle(.borderedProminent) } }
        Section("控え") { if store.codes.isEmpty { Text("読み取ったQRはここに残ります。").foregroundStyle(.secondary) }; ForEach(store.codes) { code in VStack(alignment: .leading, spacing: 5) { Text(code.label).font(.headline); Text(code.value).font(.caption).foregroundStyle(.secondary).lineLimit(1); if let date = code.expiresAt { Label("期限 \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: date < .now ? "exclamationmark.triangle.fill" : "calendar").font(.caption).foregroundStyle(date < .now ? .orange : .secondary) } }.padding(.vertical, 3) }.onDelete(perform: store.delete) }
        if !subscription.isPro { Section { Button("Proで無制限の控えと期限通知へ") { showPaywall = true } } }
    }.navigationTitle("QR控え帳").sheet(isPresented: $showScanner) { QRScanner { value in store.scannedValue = value; showScanner = false } }.sheet(isPresented: $showPaywall) { SubscriptionPaywall(name: "QR控え帳", benefits: ["無制限のQR控え", "期限通知", "暗号化バックアップ（次回）"], privacyURL: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/portfolio/privacy.html")!) } } }
}

struct QRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController { let controller = ScannerController(); controller.onCode = onCode; return controller }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    override func viewDidLoad() { super.viewDidLoad(); configure() }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); if !session.isRunning { session.startRunning() } }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); session.stopRunning() }
    private func configure() {
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput(); guard session.canAddOutput(output) else { return }; session.addOutput(output); output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.frame = view.layer.bounds; layer.videoGravity = .resizeAspectFill; view.layer.addSublayer(layer)
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) { guard let value = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }; session.stopRunning(); onCode?(value) }
}
