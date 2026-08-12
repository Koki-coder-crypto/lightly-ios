import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CompressionStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var picks: [PhotosPickerItem] = []
    @State private var showPaywall = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    presetCard
                    picker
                    if store.isProcessing { ProgressView("写真を最適化中…").padding(.vertical, 28) }
                    if !store.results.isEmpty { resultsCard }
                    planCard
                    Button { showPrivacy = true } label: { Label("写真は端末内で処理されます", systemImage: "lock.shield").font(.footnote).foregroundStyle(.secondary) }
                }.padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Lightly").navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .alert("お知らせ", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK", role: .cancel) { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "arrow.down.right.and.arrow.up.left").font(.system(size: 25, weight: .bold)).foregroundStyle(.white).frame(width: 54, height: 54).background(.blue.gradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            Text("写真を、ちょうどいい軽さに。").font(.system(.title2, design: .rounded, weight: .bold))
            Text("選んだ写真は端末内だけで処理されます。サーバーへのアップロードはありません。").font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.background, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("仕上がりを選ぶ").font(.headline)
            Picker("仕上がり", selection: $store.preset) { ForEach(CompressionStore.Preset.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Text(store.preset.description).font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    private var picker: some View {
        PhotosPicker(selection: $picks, maxSelectionCount: 30, matching: .images) {
            Label("写真を選ぶ", systemImage: "photo.on.rectangle.angled").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9)
        }.buttonStyle(.borderedProminent).tint(.blue).disabled(store.isProcessing)
            .onChange(of: picks) { _, selected in
                Task {
                    var data: [Data] = []
                    for item in selected { if let itemData = try? await item.loadTransferable(type: Data.self) { data.append(itemData) } }
                    guard !data.isEmpty else { return }
                    if store.canProcess(count: data.count, isPro: purchaseManager.isPro) { await store.compress(data, isPro: purchaseManager.isPro) } else { showPaywall = true }
                }
            }
    }
    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("最適化が完了しました", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline)
            HStack(alignment: .firstTextBaseline) { Text(ByteCountFormatter.string(fromByteCount: Int64(store.savedTotal), countStyle: .file)).font(.system(.title, design: .rounded, weight: .bold)); Text("節約（\(store.savingsPercent)%）").foregroundStyle(.secondary) }
            Text("\(store.results.count)枚  ·  \(ByteCountFormatter.string(fromByteCount: Int64(store.originalTotal), countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: Int64(store.compressedTotal), countStyle: .file))").font(.footnote).foregroundStyle(.secondary)
            ShareLink(items: store.results.map(\.url)) { Label("保存・共有する", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent).tint(.blue)
            Button("別の写真を選ぶ") { store.reset(); picks = [] }.buttonStyle(.bordered)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    private var planCard: some View {
        HStack(spacing: 12) {
            Image(systemName: purchaseManager.isPro ? "sparkles" : "circle.lefthalf.filled").font(.title3).foregroundStyle(purchaseManager.isPro ? .orange : .blue)
            VStack(alignment: .leading, spacing: 2) { Text(purchaseManager.isPro ? "Lightly Pro" : "無料プラン").font(.subheadline.weight(.semibold)); Text(purchaseManager.isPro ? "無制限の一括処理が利用できます" : "今月あと \(store.freeRemaining) 枚まで処理できます").font(.footnote).foregroundStyle(.secondary) }
            Spacer(); if !purchaseManager.isPro { Button("Pro") { showPaywall = true }.font(.subheadline.weight(.bold)) }
        }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "sparkles").font(.system(size: 38)).foregroundStyle(.orange)
            Text("もっと自由に、まとめて軽く。\nLightly Pro").font(.system(.largeTitle, design: .rounded, weight: .bold))
            VStack(alignment: .leading, spacing: 13) { Label("写真を無制限に一括処理", systemImage: "infinity"); Label("最大30枚をまとめて選択", systemImage: "rectangle.stack"); Label("広告なし・端末内処理", systemImage: "hand.raised") }
            if purchaseManager.products.isEmpty { ProgressView("プランを読み込み中…").frame(maxWidth: .infinity).padding() } else {
                ForEach(purchaseManager.products, id: \.id) { product in
                    Button { Task { await purchaseManager.purchase(product) } } label: { HStack { VStack(alignment: .leading) { Text(product.displayName).font(.headline); Text(product.description).font(.footnote).foregroundStyle(.secondary) }; Spacer(); Text(product.displayPrice).font(.headline) }.frame(maxWidth: .infinity, alignment: .leading).padding(16) }.buttonStyle(.borderedProminent).tint(.blue).disabled(purchaseManager.isLoading)
                }
            }
            Button("購入を復元") { Task { await purchaseManager.restore() } }.frame(maxWidth: .infinity).font(.footnote)
            Text("お支払いはApple IDに請求されます。サブスクリプションはApp Storeのアカウント設定からいつでも管理・解約できます。").font(.caption).foregroundStyle(.secondary)
        }.padding(24) }.navigationTitle("Lightly Pro").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } } }
    }
}

private struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("プライバシー").font(.title.bold())
            Text("Lightlyは選択された写真を端末内で処理します。写真や個人情報を当社のサーバーへ送信・保存しません。購入処理はAppleのStoreKitを利用します。")
            Link("プライバシーポリシーを開く", destination: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/privacy.html")!)
            Link("サポートを開く", destination: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/support.html")!)
        }.padding(24) }.navigationTitle("Lightly").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } } }
    }
}
