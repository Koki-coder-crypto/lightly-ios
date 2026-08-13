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
    @Published private(set) var hasStartedCurrentSession = false
    @Published private(set) var sessions: [Session] = []
    @Published var error: String?
    private var timer: Timer?
    private let key = "jp.egawa.focuspocket.sessions"
    private let freeNamespace = "jp.egawa.focuspocket"
    let freeMonthlyLimit = 12

    init() { sessions = (try? JSONDecoder().decode([Session].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? [] }
    deinit { timer?.invalidate() }
    var freeSessionsRemaining: Int { FreeUsageQuota.remaining(namespace: freeNamespace, limit: freeMonthlyLimit) }
    func startOrPause(isPro: Bool) { isRunning ? pause() : start(isPro: isPro) }
    func start(isPro: Bool) {
        guard !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !hasStartedCurrentSession {
            guard isPro || FreeUsageQuota.consume(namespace: freeNamespace, limit: freeMonthlyLimit) else {
                error = "You have used this month's free focus sessions. Pro unlocks unlimited sessions."
                return
            }
            hasStartedCurrentSession = true
        }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    func pause() { isRunning = false; timer?.invalidate() }
    func reset() { pause(); remaining = selectedMinutes * 60; hasStartedCurrentSession = false }
    func select(_ minutes: Int) { guard !isRunning else { return }; selectedMinutes = minutes; remaining = minutes * 60; hasStartedCurrentSession = false }
    private func tick() { guard remaining > 0 else { finish(); return }; remaining -= 1 }
    private func finish() { pause(); sessions.insert(Session(id: UUID(), task: task, minutes: selectedMinutes, completedAt: .now), at: 0); task = ""; remaining = selectedMinutes * 60; hasStartedCurrentSession = false; if let data = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(data, forKey: key) } }
}

struct FocusHomeView: View {
    @StateObject private var store = FocusStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showPaywall = false
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) { Text("Focus on what is in front of you.").font(.system(.title, design: .rounded, weight: .bold)); Text("Choose one task and keep going until the timer ends.").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 18) {
                    Text("\(store.remaining / 60):\(String(format: "%02d", store.remaining % 60))").font(.system(size: 74, weight: .bold, design: .rounded)).monospacedDigit()
                    TextField("What will you focus on?", text: $store.task).textFieldStyle(.roundedBorder).disabled(store.isRunning)
                    HStack { ForEach([15, 25, 45], id: \.self) { minutes in Button("\(minutes) min") { store.select(minutes) }.buttonStyle(.bordered).tint(store.selectedMinutes == minutes ? .blue : .gray).disabled(store.isRunning) } }
                    Button(store.isRunning ? "Pause" : "Start focus") { store.startOrPause(isPro: subscription.isPro) }.buttonStyle(.borderedProminent).controlSize(.large)
                    Button("Reset") { store.reset() }.font(.footnote).disabled(store.isRunning)
                }.padding(24).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                if !subscription.isPro { VStack(spacing: 8) { Text("Free plan: \(store.freeSessionsRemaining)/\(store.freeMonthlyLimit) sessions left this month").font(.caption).foregroundStyle(.secondary); Button("Unlock unlimited focus history with Pro") { showPaywall = true }.font(.subheadline.weight(.semibold)) } }
                VStack(alignment: .leading, spacing: 12) { Text("Completed sessions").font(.headline); if store.sessions.isEmpty { Text("Your completed sessions will appear here.").foregroundStyle(.secondary) } else { ForEach(store.sessions.prefix(5)) { session in HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); VStack(alignment: .leading) { Text(session.task); Text("\(session.minutes) min · \(session.completedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }; Spacer() } } } }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(20) }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Focus Pocket").sheet(isPresented: $showPaywall) { SubscriptionPaywall(name: "Focus Pocket", benefits: ["Unlimited focus sessions", "Saved focus history", "15, 25, and 45 minute modes"], privacyURL: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/portfolio/privacy.html")!) }.alert("Notice", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(store.error ?? "") }
        }
    }
}
