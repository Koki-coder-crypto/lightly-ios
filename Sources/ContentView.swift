import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var store: CompressionStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var picks: [PhotosPickerItem] = []
    @State private var showPrivacy = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    presetPicker
                    planStatus
                    action
                    if store.isProcessing { progress }
                    if !store.results.isEmpty { resultCard }
                    privacy
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Lightly")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("お知らせ", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK", role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color.indigo.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text("写真を、軽く。")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("選んだ写真だけを端末内で圧縮します。アップロードも、アカウント登録も必要ありません。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("仕上がり").font(.headline)
            Picker("仕上がり", selection: $store.preset) {
                ForEach(CompressionStore.Preset.allCases) { preset in Text(preset.rawValue).tag(preset) }
            }
            .pickerStyle(.segmented)
            Text("「おすすめ」は見た目を保ちながら、共有しやすいサイズに整えます。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var action: some View {
        PhotosPicker(selection: $picks, maxSelectionCount: 30, matching: .images) {
            Label("写真を選ぶ", systemImage: "photo.on.rectangle.angled")
                .font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 7)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .disabled(store.isProcessing)
        .onChange(of: picks) { _, selected in
            Task {
                var data: [Data] = []
                for item in selected {
                    if let imageData = try? await item.loadTransferable(type: Data.self) {
                        data.append(imageData)
                    }
                }
                if !store.canProcess(count: data.count, isPro: purchaseManager.isPro) {
                    showPaywall = true
                    return
                }
                await store.compress(data, isPro: purchaseManager.isPro)
            }
        }
    }

    private var planStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: purchaseManager.isPro ? "sparkles" : "leaf")
                .foregroundStyle(purchaseManager.isPro ? .orange : .green)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(purchaseManager.isPro ? "Lightly Pro" : "無料プラン")
                    .font(.subheadline.weight(.semibold))
                Text(purchaseManager.isPro ? "無制限で軽量化できます" : "今月あと \(store.freeRemaining) 枚")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if !purchaseManager.isPro { Button("Proを見る") { showPaywall = true }.font(.subheadline.weight(.semibold)) }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var progress: some View {
        VStack(spacing: 12) { ProgressView(); Text("端末内で軽量化しています…").font(.subheadline).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity).padding(28)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("軽量化が完了しました").font(.headline)
            HStack(alignment: .firstTextBaseline) {
                Text(ByteCountFormatter.string(fromByteCount: Int64(store.savedTotal), countStyle: .file))
                    .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.indigo)
                Text("節約").foregroundStyle(.secondary)
            }
            Text("\(store.results.count)枚  ·  \(ByteCountFormatter.string(fromByteCount: Int64(store.originalTotal), countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: Int64(store.compressedTotal), countStyle: .file))")
                .font(.footnote).foregroundStyle(.secondary)
            ShareLink(items: store.results.map(\.url)) { Label("共有または保存", systemImage: "square.and.arrow.up") }
                .buttonStyle(.borderedProminent).tint(.indigo)
            Button("新しく選ぶ") { store.reset(); picks = [] }.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var privacy: some View {
        Button { showPrivacy = true } label: {
            Label("写真は端末の外に送信されません", systemImage: "lock.shield")
                .font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

private struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .semibold)).foregroundStyle(.orange)
                    Text("もっと軽く、もっと自由に。")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    VStack(alignment: .leading, spacing: 12) {
                        Label("毎月の軽量化が無制限", systemImage: "infinity")
                        Label("最大30枚をまとめて処理", systemImage: "rectangle.stack")
                        Label("広告なし・登録なしのまま", systemImage: "hand.raised")
                    }.font(.body)

                    if purchaseManager.products.isEmpty {
                        ProgressView("プランを読み込んでいます")
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        ForEach(purchaseManager.products, id: \.id) { product in
                            Button {
                                Task { await purchaseManager.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName).font(.headline)
                                        Text(product.description).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice).font(.headline)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            }
                            .buttonStyle(.borderedProminent).tint(.indigo)
                            .disabled(purchaseManager.isLoading)
                        }
                    }
                    Button("購入を復元") { Task { await purchaseManager.restore() } }
                        .frame(maxWidth: .infinity).font(.footnote)
                    Text("購入はApple IDで管理され、いつでも設定からキャンセルできます。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            .navigationTitle("Lightly Pro")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .alert("お知らせ", isPresented: Binding(get: { purchaseManager.errorMessage != nil }, set: { if !$0 { purchaseManager.errorMessage = nil } })) {
                Button("OK", role: .cancel) { purchaseManager.errorMessage = nil }
            } message: { Text(purchaseManager.errorMessage ?? "") }
        }
    }
}

private struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("プライバシー").font(.title.bold())
            Text("Lightlyは、あなたが選択した写真を圧縮するためだけに写真ライブラリへアクセスします。写真、利用状況、個人情報をサーバーへ送信・収集・共有しません。圧縮後のファイルは共有するまで端末の一時領域に保存されます。")
            Link("プライバシーポリシーを開く", destination: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/privacy.html")!)
            Link("サポートを開く", destination: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/support.html")!)
                .foregroundStyle(.secondary)
        }.padding(24) }.navigationTitle("Lightly").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } } }
    }
}
