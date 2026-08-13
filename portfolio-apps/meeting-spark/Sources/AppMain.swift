import AVFoundation
import SwiftUI

@main
struct MeetingSparkApp: App {
    @StateObject private var subscription = SubscriptionManager(monthlyID: "jp.egawa.meetingspark.pro.monthly", yearlyID: "jp.egawa.meetingspark.pro.yearly")

    var body: some Scene {
        WindowGroup { MeetingHomeView().environmentObject(subscription) }
    }
}

@MainActor
final class VoiceStore: NSObject, ObservableObject, AVAudioRecorderDelegate {
    struct Memo: Identifiable, Codable {
        let id: UUID
        let title: String
        let action: String
        let fileName: String
        let duration: TimeInterval
        let createdAt: Date
    }

    @Published var title = ""
    @Published var nextAction = ""
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var memos: [Memo] = []
    @Published var error: String?
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private let key = "jp.egawa.meetingspark.memos"
    private let freeNamespace = "jp.egawa.meetingspark"
    let freeMonthlyLimit = 12

    override init() {
        super.init()
        memos = (try? JSONDecoder().decode([Memo].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? []
    }

    var freeMemosRemaining: Int { FreeUsageQuota.remaining(namespace: freeNamespace, limit: freeMonthlyLimit) }
    func toggleRecording(isPro: Bool) { isRecording ? stopRecording() : startRecording(isPro: isPro) }

    func startRecording(isPro: Bool) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Enter a meeting title first."
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                if granted { self?.begin(isPro: isPro) }
            else { self?.error = "Allow microphone access to record a voice memo." }
            }
        }
    }

    private func begin(isPro: Bool) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let audioRecorder = try AVAudioRecorder(
                url: fileURL(),
                settings: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            )
            guard isPro || FreeUsageQuota.consume(namespace: freeNamespace, limit: freeMonthlyLimit) else {
                error = "You have used this month's free recordings. Pro unlocks unlimited recordings."
                return
            }
            recorder = audioRecorder
            audioRecorder.record()
            isRecording = true
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed += 1 }
            }
        } catch {
            self.error = "Recording could not be started."
        }
    }

    func stopRecording() {
        guard let recorder else { return }
        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        memos.insert(Memo(id: UUID(), title: title, action: nextAction, fileName: recorder.url.lastPathComponent, duration: elapsed, createdAt: .now), at: 0)
        title = ""
        nextAction = ""
        persist()
    }

    func play(_ memo: Memo) {
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: directory.appendingPathComponent(memo.fileName))
        player?.play()
    }

    private var directory: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("MeetingMemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func fileURL() -> URL { directory.appendingPathComponent("memo-\(UUID()).m4a") }
    private func persist() {
        if let data = try? JSONEncoder().encode(memos) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct MeetingHomeView: View {
    @StateObject private var store = VoiceStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Capture the next action after a meeting.", systemImage: "mic.fill")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("Keep a meeting title, short voice memo, and next action together on this device.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section(store.isRecording ? "Recording" : "New memo") {
                    TextField("Meeting title", text: $store.title).disabled(store.isRecording)
                    TextField("Next action (optional)", text: $store.nextAction).disabled(store.isRecording)
                    HStack {
                        Text("\(Int(store.elapsed / 60)):\(String(format: "%02d", Int(store.elapsed) % 60))").monospacedDigit()
                        Spacer()
                        Button { store.toggleRecording(isPro: subscription.isPro) } label: {
                            Label(store.isRecording ? "Stop recording" : "Start recording", systemImage: store.isRecording ? "stop.circle.fill" : "record.circle")
                        }
                        .buttonStyle(.borderedProminent).tint(store.isRecording ? .red : .blue)
                    }
                }
                Section("Recent memos") {
                    if store.memos.isEmpty { Text("Your recorded memos will appear here.").foregroundStyle(.secondary) }
                    ForEach(store.memos) { memo in
                        HStack {
                            Button { store.play(memo) } label: { Image(systemName: "play.circle.fill").font(.title2) }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(memo.title).font(.headline)
                                if !memo.action.isEmpty { Text("Next: \(memo.action)").font(.subheadline).foregroundStyle(.secondary) }
                                Text("\(Int(memo.duration)) sec  \(memo.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                }
                if !subscription.isPro {
                    Section {
                        Text("Free plan: \(store.freeMemosRemaining)/\(store.freeMonthlyLimit) recordings left this month").font(.caption).foregroundStyle(.secondary)
                        Button("Unlock unlimited recordings with Pro") { showPaywall = true }
                    }
                }
            }
            .navigationTitle("Meeting Spark")
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywall(name: "Meeting Spark", benefits: ["Unlimited voice memos", "Meeting titles and next actions", "Audio stored only on your device"], privacyURL: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/portfolio/privacy.html")!)
            }
            .alert("Notice", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(store.error ?? "") }
        }
    }
}
