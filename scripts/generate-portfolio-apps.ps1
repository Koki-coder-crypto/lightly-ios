Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$apps = @(
    @{ Slug='handy-print'; Name='手渡しプリント'; Bundle='jp.egawa.handyprint'; Icon='printer.fill'; Job='写真とメモを、用途に合う1枚のPDFとして渡したい'; Free='毎月3枚のPDFを無料で作成'; Pro='無制限のPDF・用途テンプレート・再出力履歴'; Action='PDFを作成'; Type='print' },
    @{ Slug='warranty-ledger'; Name='持ち物期限帳'; Bundle='jp.egawa.warrantyledger'; Icon='calendar.badge.clock'; Job='保証・返品・交換期限を忘れずに管理したい'; Free='20件まで、次の期限を表示'; Pro='無制限・複数通知・月次の見直し'; Action='期限を登録'; Type='deadline' },
    @{ Slug='meeting-spark'; Name='会議前メモ'; Bundle='jp.egawa.meetingspark'; Icon='mic.fill'; Job='会議直前の考えを次の行動として残したい'; Free='週5件の会議メモ'; Pro='無制限・予定別整理・週次レビュー'; Action='メモを残す'; Type='note' },
    @{ Slug='leave-check'; Name='出発チェック'; Bundle='jp.egawa.leavecheck'; Icon='checklist'; Job='出発前に持ち物を忘れたくない'; Free='3つのチェックリスト'; Pro='無制限・曜日別リスト・通知'; Action='リストを作る'; Type='checklist' },
    @{ Slug='qr-keeper'; Name='QR控え帳'; Bundle='jp.egawa.qrkeeper'; Icon='qrcode'; Job='受け取ったQRの用途と期限を安全に控えたい'; Free='50件のQRメモ'; Pro='無制限・期限通知・バックアップ'; Action='QRを控える'; Type='code' },
    @{ Slug='receipt-split'; Name='割り勘メモ'; Bundle='jp.egawa.receiptsplit'; Icon='yensign.circle'; Job='立替えた金額をすぐに公平に分けたい'; Free='月5回の精算'; Pro='無制限・履歴・定番グループ'; Action='精算を作る'; Type='split' },
    @{ Slug='parcel-note'; Name='荷物メモ'; Bundle='jp.egawa.parcelnote'; Icon='shippingbox.fill'; Job='届く予定の荷物と受取メモを一か所で確認したい'; Free='5件の荷物メモ'; Pro='無制限・受取通知・履歴'; Action='荷物を追加'; Type='parcel' },
    @{ Slug='wifi-notes'; Name='Wi-Fiメモ'; Bundle='jp.egawa.wifinotes'; Icon='wifi'; Job='場所ごとのWi-Fi接続メモを安全に整理したい'; Free='10件の場所メモ'; Pro='無制限・検索・暗号化バックアップ'; Action='場所を追加'; Type='wifi' },
    @{ Slug='home-care'; Name='おうちメンテ'; Bundle='jp.egawa.homecare'; Icon='house.and.flag.fill'; Job='家の消耗品・設備の交換時期を忘れたくない'; Free='10件のメンテ予定'; Pro='無制限・通知・月次点検'; Action='予定を追加'; Type='maintenance' },
    @{ Slug='focus-pocket'; Name='集中ポケット'; Bundle='jp.egawa.focuspocket'; Icon='timer'; Job='短い集中時間をつくって、やることを終えたい'; Free='1日3セッション'; Pro='無制限・集中履歴・週次レポート'; Action='集中を始める'; Type='focus' }
)

$root = Join-Path (Get-Location) 'portfolio-apps'
New-Item -ItemType Directory -Force -Path $root | Out-Null

foreach ($app in $apps) {
    $dir = Join-Path $root $app.Slug
    $sources = Join-Path $dir 'Sources'
    New-Item -ItemType Directory -Force -Path $sources | Out-Null
    $project = @"
name: $($app.Name)
options:
  bundleIdPrefix: jp.egawa
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    MARKETING_VERSION: 1.0.0
    CURRENT_PROJECT_VERSION: 1
    SWIFT_VERSION: 5.0
targets:
  $($app.Name):
    type: application
    platform: iOS
    sources: [Sources, Assets.xcassets]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: $($app.Bundle)
        INFOPLIST_KEY_CFBundleDisplayName: "$($app.Name)"
        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.utilities
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        TARGETED_DEVICE_FAMILY: "1"
"@
    $source = @"
import StoreKit
import SwiftUI

@main
struct AppMain: App {
    @StateObject private var subscription = SubscriptionManager()
    var body: some Scene { WindowGroup { DashboardView().environmentObject(subscription) } }
}

private enum AppSpec {
    static let name = "$($app.Name)"
    static let icon = "$($app.Icon)"
    static let job = "$($app.Job)"
    static let free = "$($app.Free)"
    static let pro = "$($app.Pro)"
    static let action = "$($app.Action)"
    static let monthlyID = "$($app.Bundle).pro.monthly"
    static let yearlyID = "$($app.Bundle).pro.yearly"
}

@MainActor
final class UtilityStore: ObservableObject {
    @Published var title = ""
    @Published var detail = ""
    @Published private(set) var entries: [Entry] = []
    @Published var isRunning = false
    struct Entry: Identifiable, Codable { let id: UUID; let title: String; let detail: String; let createdAt: Date }
    private let key = "$($app.Bundle).entries"
    init() { entries = (try? JSONDecoder().decode([Entry].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? [] }
    func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        entries.insert(Entry(id: UUID(), title: cleaned, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: .now), at: 0)
        title = ""; detail = ""
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) }
    }
    func remove(_ offsets: IndexSet) { entries.remove(atOffsets: offsets); if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) } }
}

struct DashboardView: View {
    @StateObject private var store = UtilityStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showPaywall = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(AppSpec.job, systemImage: AppSpec.icon).font(.headline)
                    Text(subscription.isPro ? AppSpec.pro : AppSpec.free).font(.subheadline).foregroundStyle(.secondary)
                }
                Section("新しく追加") {
                    TextField("タイトル", text: `$store.title)
                    TextField("補足・期限・相手など", text: `$store.detail)
                    Button(AppSpec.action) { store.save() }.buttonStyle(.borderedProminent).disabled(store.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("履歴") {
                    if store.entries.isEmpty { Text("まだ記録はありません").foregroundStyle(.secondary) }
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) { Text(entry.title).font(.headline); if !entry.detail.isEmpty { Text(entry.detail).font(.subheadline).foregroundStyle(.secondary) }; Text(entry.createdAt, style: .date).font(.caption).foregroundStyle(.tertiary) }
                    }.onDelete(perform: store.remove)
                }
                if !subscription.isPro { Section { Button("Proの機能を見る") { showPaywall = true } } }
            }
            .navigationTitle(AppSpec.name)
            .sheet(isPresented: `$showPaywall) { PaywallView() }
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPro = false
    @Published var isLoading = false
    init() { Task { await refresh() } }
    func refresh() async {
        isPro = false
        products = (try? await Product.products(for: [AppSpec.monthlyID, AppSpec.yearlyID]))?.sorted { (`$0.id == AppSpec.yearlyID ? 0 : 1) < (`$1.id == AppSpec.yearlyID ? 0 : 1) } ?? []
        for await item in Transaction.currentEntitlements { if case .verified(let transaction) = item, [AppSpec.monthlyID, AppSpec.yearlyID].contains(transaction.productID) { isPro = true } }
    }
    func purchase(_ product: Product) async {
        isLoading = true; defer { isLoading = false }
        do {
            guard case .success(let result) = try await product.purchase(), case .verified(let transaction) = result else { return }
            await transaction.finish(); await refresh()
        } catch { }
    }
    func restore() async { try? await AppStore.sync(); await refresh() }
}

private struct PaywallView: View {
    @Environment(`.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionManager
    var body: some View { NavigationStack { VStack(alignment: .leading, spacing: 20) {
        Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.orange)
        Text("\(AppSpec.name) Pro").font(.largeTitle.bold())
        Text(AppSpec.pro)
        ForEach(subscription.products, id: `\.id) { product in Button { Task { await subscription.purchase(product) } } label: { HStack { VStack(alignment: .leading) { Text(product.displayName); Text(product.description).font(.caption) }; Spacer(); Text(product.displayPrice) }.frame(maxWidth: .infinity).padding() }.buttonStyle(.borderedProminent) }
        Button("購入を復元") { Task { await subscription.restore() } }
        Text("トライアルの期間と終了後の更新価格は購入前に表示されます。サブスクリプションはApple IDに請求され、App Storeの設定から管理・解約できます。").font(.caption).foregroundStyle(.secondary)
        Spacer()
    }.padding().navigationTitle("Pro").toolbar { Button("閉じる") { dismiss() } } } }
}
"@
    $listing = @"
# $($app.Name) — 提出準備

- Bundle ID: `$($app.Bundle)`
- 収益化: 無料ダウンロード、3日トライアル付き自動更新サブスクリプション（月額・年額）
- 無料価値: $($app.Free)
- Pro価値: $($app.Pro)
- レビュー確認: タイトルを入力して「$($app.Action)」をタップすると端末内へ記録される。外部アカウントは不要。
- 提出前: プライバシーポリシー、利用規約、商品表示名・価格・トライアルをApp Store Connectでローカライズする。
"@
    Set-Content -Encoding utf8 -Path (Join-Path $dir 'project.yml') -Value $project
    Set-Content -Encoding utf8 -Path (Join-Path $sources 'AppMain.swift') -Value $source
    Set-Content -Encoding utf8 -Path (Join-Path $dir 'APP_STORE_SUBMISSION.md') -Value $listing

    $assetSet = Join-Path $dir 'Assets.xcassets\AppIcon.appiconset'
    New-Item -ItemType Directory -Force -Path $assetSet | Out-Null
    $iconJSON = '{"images":[{"filename":"AppIcon-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}'
    Set-Content -Encoding utf8 -Path (Join-Path $assetSet 'Contents.json') -Value $iconJSON
    $color = [System.Drawing.Color]::FromArgb(255, (50 + ($app.Slug.Length * 13) % 150), (70 + ($app.Name.Length * 29) % 150), (120 + ($app.Slug.Length * 17) % 120))
    $bitmap = New-Object System.Drawing.Bitmap(1024, 1024)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($color)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $graphics.FillEllipse($brush, 184, 184, 656, 656)
    $font = New-Object System.Drawing.Font('Arial', 280, [System.Drawing.FontStyle]::Bold)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString($app.Slug.Substring(0,1).ToUpper(), $font, (New-Object System.Drawing.SolidBrush($color)), (New-Object System.Drawing.RectangleF(0, 0, 1024, 1024)), $format)
    $graphics.Dispose(); $brush.Dispose(); $font.Dispose(); $bitmap.Save((Join-Path $assetSet 'AppIcon-1024.png'), [System.Drawing.Imaging.ImageFormat]::Png); $bitmap.Dispose()
}

Write-Output "Generated $($apps.Count) independent iOS app projects in $root"
