import SwiftUI

@main
struct FocusPocketApp: App {
    @StateObject private var subscription = SubscriptionManager(monthlyID: "jp.egawa.focuspocket.pro.monthly", yearlyID: "jp.egawa.focuspocket.pro.yearly")
    var body: some Scene { WindowGroup { FocusHomeView().environmentObject(subscription) } }
}

@MainActor
final class FocusStore: ObservableObject {
    struct Session: Identifiable, Codable { let id: UUID; let task: String; let minutes: Int; let completedAt: Date }
    @Published var task = ""
    @Published var selectedMinutes = 25
    @Published var remaining = 25 * 60
    @Published var isRunning = false
    @Published private(set) var sessions: [Session] = []
    private var timer: Timer?
    private let key = "jp.egawa.focuspocket.sessions"

    init() { sessions = (try? JSONDecoder().decode([Session].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? [] }
    deinit { timer?.invalidate() }
    func startOrPause() { isRunning ? pause() : start() }
    func start() {
        guard !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    func pause() { isRunning = false; timer?.invalidate() }
    func reset() { pause(); remaining = selectedMinutes * 60 }
    func select(_ minutes: Int) { guard !isRunning else { return }; selectedMinutes = minutes; remaining = minutes * 60 }
    private func tick() { guard remaining > 0 else { finish(); return }; remaining -= 1 }
    private func finish() { pause(); sessions.insert(Session(id: UUID(), task: task, minutes: selectedMinutes, completedAt: .now), at: 0); task = ""; remaining = selectedMinutes * 60; if let data = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(data, forKey: key) } }
}

struct FocusHomeView: View {
    @StateObject private var store = FocusStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showPaywall = false
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) { Text("今ここに集中する。").font(.system(.title, design: .rounded, weight: .bold)); Text("やることを一つだけ決めて、タイマーが終わるまで進めます。").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 18) {
                    Text("\(store.remaining / 60):\(String(format: "%02d", store.remaining % 60))").font(.system(size: 74, weight: .bold, design: .rounded)).monospacedDigit()
                    TextField("今やること", text: $store.task).textFieldStyle(.roundedBorder).disabled(store.isRunning)
                    HStack { ForEach([15, 25, 45], id: \.self) { minutes in Button("\(minutes)分") { store.select(minutes) }.buttonStyle(.bordered).tint(store.selectedMinutes == minutes ? .blue : .gray).disabled(store.isRunning) } }
                    Button(store.isRunning ? "一時停止" : "集中を始める") { store.startOrPause() }.buttonStyle(.borderedProminent).controlSize(.large)
                    Button("リセット") { store.reset() }.font(.footnote).disabled(store.isRunning)
                }.padding(24).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                if !subscription.isPro { Button("Proで無制限の集中履歴へ") { showPaywall = true }.font(.subheadline.weight(.semibold)) }
                VStack(alignment: .leading, spacing: 12) { Text("完了した集中").font(.headline); if store.sessions.isEmpty { Text("最初の1回を始めると、ここに記録されます。").foregroundStyle(.secondary) } else { ForEach(store.sessions.prefix(5)) { session in HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); VStack(alignment: .leading) { Text(session.task); Text("\(session.minutes)分 · \(session.completedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }; Spacer() } } } }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(20) }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("集中ポケット").sheet(isPresented: $showPaywall) { SubscriptionPaywall(name: "集中ポケット", benefits: ["無制限の集中セッション", "集中履歴と週次レビュー", "ホーム画面ウィジェット（次回）"], privacyURL: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/portfolio/privacy.html")!) }
        }
    }
}
