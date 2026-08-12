import Photos
import SwiftUI
import UIKit

@main
struct RoomRollApp: App {
    @StateObject private var subscription = SubscriptionManager(monthlyID: "jp.egawa.roomroll.pro.monthly", yearlyID: "jp.egawa.roomroll.pro.yearly")
    var body: some Scene { WindowGroup { RoomRollView().environmentObject(subscription) } }
}

struct MediaItem: Identifiable {
    let id: String
    let asset: PHAsset
    let thumbnail: UIImage
    let bytes: Int
    let createdAt: Date?
    var sizeText: String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }
}

enum TidyCategory: CaseIterable, Hashable, Identifiable {
    case screenshots
    case longVideos
    case largePhotos
    var id: Self { self }
    var title: String { switch self {
        case .screenshots: String(localized: "スクリーンショット")
        case .longVideos: String(localized: "長いビデオ")
        case .largePhotos: String(localized: "最近の大きい写真")
    } }
    var icon: String { switch self { case .screenshots: "rectangle.on.rectangle"; case .longVideos: "video.fill"; case .largePhotos: "photo.fill" } }
    var detail: String { switch self {
        case .screenshots: String(localized: "見返さない画像を確認")
        case .longVideos: String(localized: "再生時間順に見直す")
        case .largePhotos: String(localized: "最近追加した写真から優先表示")
    } }
}

@MainActor
final class RoomRollStore: ObservableObject {
    @Published private(set) var items: [TidyCategory: [MediaItem]] = [:]
    @Published private(set) var isScanning = false
    @Published private(set) var authorization: PHAuthorizationStatus = .notDetermined
    @Published var error: String?

    init() { authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard isAuthorized else { error = "写真へのアクセスを許可すると、端末内で容量の大きい項目を見直せます。"; return }
        await scan()
    }
    func scan() async {
        guard isAuthorized else { await requestAccess(); return }
        isScanning = true; error = nil
        defer { isScanning = false }
        var result: [TidyCategory: [MediaItem]] = [:]
        let all = PHAsset.fetchAssets(with: .image, options: orderedOptions())
        let images = await loadItems(from: all, cap: 100)
        result[.screenshots] = images.filter { $0.asset.mediaSubtypes.contains(.photoScreenshot) }.sorted { $0.createdAt ?? .distantPast > $1.createdAt ?? .distantPast }
        result[.largePhotos] = images.filter { !$0.asset.mediaSubtypes.contains(.photoScreenshot) }.sorted { $0.bytes > $1.bytes }.prefix(40).map { $0 }
        let videos = PHAsset.fetchAssets(with: .video, options: orderedOptions())
        result[.longVideos] = await loadItems(from: videos, cap: 60).sorted { $0.asset.duration > $1.asset.duration }
        items = result
    }

    var reviewCount: Int { items.values.reduce(0) { $0 + $1.count } }
    func count(for category: TidyCategory) -> Int { items[category]?.count ?? 0 }
    func delete(_ selected: [MediaItem]) async -> Bool {
        guard !selected.isEmpty else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(selected.map(\.asset) as NSArray) }
            await scan(); return true
        } catch { self.error = "写真の削除を完了できませんでした。写真アプリの権限を確認してください。"; return false }
    }
    private func orderedOptions() -> PHFetchOptions { let options = PHFetchOptions(); options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]; return options }
    private func loadItems(from assets: PHFetchResult<PHAsset>, cap: Int) async -> [MediaItem] {
        let count = min(assets.count, cap)
        var result: [MediaItem] = []
        for index in 0..<count { if let item = await makeItem(assets.object(at: index)) { result.append(item) } }
        return result
    }
    private func makeItem(_ asset: PHAsset) async -> MediaItem? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions(); options.deliveryMode = .fastFormat; options.resizeMode = .fast; options.isNetworkAccessAllowed = false
        return await withCheckedContinuation { continuation in
            if asset.mediaType == .video {
                // `requestImage` produces a real poster frame for a video. We do not need
                // its file size because the video review screen shows its duration instead.
                manager.requestImage(for: asset, targetSize: CGSize(width: 360, height: 360), contentMode: .aspectFill, options: options) { image, _ in
                    let thumbnail = image ?? UIImage(systemName: "video.fill")!
                    continuation.resume(returning: MediaItem(id: asset.localIdentifier, asset: asset, thumbnail: thumbnail, bytes: 0, createdAt: asset.creationDate))
                }
            } else {
                // The original data size is the reliable ordering signal for the large-photo list.
                manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    let image = UIImage(data: data ?? Data()) ?? UIImage(systemName: "photo.fill")!
                    let thumbnail = image.preparingThumbnail(of: CGSize(width: 180, height: 180)) ?? image
                    continuation.resume(returning: MediaItem(id: asset.localIdentifier, asset: asset, thumbnail: thumbnail, bytes: data?.count ?? 0, createdAt: asset.creationDate))
                }
            }
        }
    }
}

struct RoomRollView: View {
    @StateObject private var store = RoomRollStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var category: TidyCategory?
    @State private var showPaywall = false
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                header
                if store.isAuthorized { dashboard } else { permissionCard }
                if store.isScanning { ProgressView("写真ライブラリを端末内で確認中…").frame(maxWidth: .infinity).padding(24) }
                if !subscription.isPro { UsageAllowanceCard(remaining: FreeUsageQuota.remaining(namespace: "jp.egawa.roomroll", limit: 30), limit: 30, actionTitle: "Proの機能を見る") { showPaywall = true } }
            }.padding(20) }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Photo Cleaner")
                .task { if store.isAuthorized { await store.scan() } }
                .sheet(item: $category) { ReviewView(category: $0, items: store.items[$0] ?? [], store: store) }
                .sheet(isPresented: $showPaywall) { SubscriptionPaywall(name: "Photo Cleaner", benefits: ["無制限の項目レビュー", "最近の大きい写真と長い動画を優先表示", "端末内だけで安全に整理"], privacyURL: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/privacy.html")!) }
                .alert("Photo Cleaner", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(store.error ?? "") }
        }
    }
    private var header: some View { VStack(alignment: .leading, spacing: 12) {
        HStack { Image(systemName: "sparkles.rectangle.stack.fill").font(.title2).foregroundStyle(.white).frame(width: 48, height: 48).background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous)); Spacer(); Label("端末内で処理", systemImage: "lock.fill").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
        Text("写真を、気持ちよく整理する。").font(.system(.title2, design: .rounded, weight: .bold))
        Text("スクリーンショット、長いビデオ、最近の大きい写真を、削除前に一つずつ確認できます。写真をアップロードせず、自動で削除することもありません。").foregroundStyle(.secondary)
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    private var permissionCard: some View { VStack(alignment: .leading, spacing: 12) { Label("写真へのアクセスが必要です", systemImage: "photo.on.rectangle.angled").font(.headline); Text("許可した範囲だけを端末内で見直します。削除は、選んだ項目を確認した場合にだけ実行され、写真アプリの「最近削除した項目」に移動します。").font(.subheadline).foregroundStyle(.secondary); if store.authorization == .denied || store.authorization == .restricted { PrimaryActionButton(title: "設定を開く", systemImage: "gear") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } } else { PrimaryActionButton(title: "写真を確認する", systemImage: "checkmark.shield") { Task { await store.requestAccess() } } } }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    private var dashboard: some View { VStack(spacing: 14) {
        HStack(alignment: .firstTextBaseline) { VStack(alignment: .leading, spacing: 4) { Text("レビュー候補").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary); Text("\(store.reviewCount)").font(.system(.largeTitle, design: .rounded, weight: .bold)); Text("削除するかは、すべてあなたが決めます").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { Task { await store.scan() } } label: { Image(systemName: "arrow.clockwise").font(.headline).frame(width: 42, height: 42).background(Color.indigo.opacity(0.12), in: Circle()) }.buttonStyle(.plain).accessibilityLabel("ライブラリを再確認") }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        ForEach(TidyCategory.allCases) { item in let count = store.count(for: item); Button { category = item } label: { HStack(spacing: 14) { Image(systemName: item.icon).font(.title2).foregroundStyle(.indigo).frame(width: 32); VStack(alignment: .leading, spacing: 3) { Text(item.title).font(.headline); Text(count == 0 ? item.detail : "\(count)件を確認できます") .font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(count == 0 ? "" : "\(count)").font(.subheadline.monospacedDigit().weight(.bold)).foregroundStyle(.secondary); Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary) }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous)) }.buttonStyle(.plain) }
    }.frame(maxWidth: .infinity) }
}

private struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionManager
    let category: TidyCategory
    let items: [MediaItem]
    @ObservedObject var store: RoomRollStore
    @State private var selected = Set<String>()
    @State private var confirming = false
    @State private var deleting = false
    @State private var showSwipeReview = false
    var selectedItems: [MediaItem] { items.filter { selected.contains($0.id) } }
    private var freeRemaining: Int { FreeUsageQuota.remaining(namespace: "jp.egawa.roomroll", limit: 30) }
    var body: some View { NavigationStack { Group { if items.isEmpty { ContentUnavailableView("確認する項目はありません", systemImage: "checkmark.circle", description: Text("このカテゴリに表示できる項目はありません。")) } else { List(items) { item in Button { if selected.contains(item.id) { selected.remove(item.id) } else if subscription.isPro || selected.count < freeRemaining { selected.insert(item.id) } else { store.error = "無料版の今月の削除枠に達しました。Photo Cleaner Proなら無制限に整理できます。" } } label: { HStack(spacing: 12) { Image(uiImage: item.thumbnail).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 3) { Text(category == .longVideos ? durationText(item.asset.duration) : item.sizeText).font(.headline); if let date = item.createdAt { Text(date, style: .date).font(.caption).foregroundStyle(.secondary) } }; Spacer(); Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected.contains(item.id) ? .red : .secondary) } }.buttonStyle(.plain).accessibilityValue(selected.contains(item.id) ? "選択済み" : "未選択") } } }.navigationTitle(category.title).toolbar { ToolbarItem(placement: .topBarLeading) { Button("スワイプで確認") { showSwipeReview = true } }; ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() } }; ToolbarItem(placement: .bottomBar) { Button(role: .destructive) { confirming = true } label: { Label("\(selected.count)件を写真から削除", systemImage: "trash") }.disabled(selected.isEmpty || deleting) } }.safeAreaInset(edge: .bottom) { VStack(spacing: 4) { if !subscription.isPro { Text("無料版は今月あと \(freeRemaining) 件まで削除できます").font(.caption).foregroundStyle(.secondary) }; Text("削除した項目は「最近削除した項目」に移動します").font(.caption2).foregroundStyle(.secondary) }.padding(.vertical, 8) }.confirmationDialog("写真アプリの「最近削除した項目」に移動します", isPresented: $confirming, titleVisibility: .visible) { Button("\(selected.count)件を削除", role: .destructive) { Task { deleting = true; if await store.delete(selectedItems) { if !subscription.isPro { for _ in selectedItems { _ = FreeUsageQuota.consume(namespace: "jp.egawa.roomroll", limit: 30) } }; dismiss() }; deleting = false } }; Button("キャンセル", role: .cancel) {} } message: { Text("削除後も写真アプリで復元または完全削除を確認できます。") }.fullScreenCover(isPresented: $showSwipeReview) { SwipeReviewView(category: category, items: items, store: store) } } }

    private func durationText(_ duration: TimeInterval) -> String { "\(Int(duration / 60))分 \(Int(duration) % 60)秒" }
}

/// A fast, reversible review mode. Decisions remain staged in memory until the
/// user explicitly confirms the final deletion dialog.
private struct SwipeReviewView: View {
    private enum Decision: Equatable { case keep, remove }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionManager
    let category: TidyCategory
    let items: [MediaItem]
    @ObservedObject var store: RoomRollStore

    @State private var position = 0
    @State private var history: [Decision] = []
    @State private var pendingRemoval = Set<String>()
    @State private var cardOffset = CGSize.zero
    @State private var showConfirmation = false
    @State private var isDeleting = false

    private var current: MediaItem? { position < items.count ? items[position] : nil }
    private var freeRemaining: Int { FreeUsageQuota.remaining(namespace: "jp.egawa.roomroll", limit: 30) }
    private var completed: Bool { position >= items.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                progress
                if let item = current {
                    card(item)
                    decisionControls
                } else {
                    completion
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取り消す", systemImage: "arrow.uturn.backward") { undo() }
                        .disabled(history.isEmpty || isDeleting)
                }
            }
            .confirmationDialog("写真アプリの「最近削除した項目」に移動します", isPresented: $showConfirmation, titleVisibility: .visible) {
                Button("\(pendingRemoval.count)件を削除", role: .destructive) { removeMarkedItems() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("選んだ項目だけを削除します。削除後も写真アプリで復元または完全削除を確認できます。")
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(min(position + 1, items.count)) / \(items.count)")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("削除候補 \(pendingRemoval.count)件")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            ProgressView(value: Double(position), total: Double(max(items.count, 1)))
                .tint(.indigo)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(items.count)件中\(min(position + 1, items.count))件目。削除候補は\(pendingRemoval.count)件")
    }

    private func card(_ item: MediaItem) -> some View {
        ZStack(alignment: .top) {
            Image(uiImage: item.thumbnail)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 490)
                .background(.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            HStack {
                if cardOffset.width < -20 { Label("削除", systemImage: "trash.fill").foregroundStyle(.white).padding(10).background(.red.opacity(0.88), in: Capsule()) }
                Spacer()
                if cardOffset.width > 20 { Label("残す", systemImage: "heart.fill").foregroundStyle(.white).padding(10).background(.green.opacity(0.88), in: Capsule()) }
            }
            .padding(16)
        }
        .rotationEffect(.degrees(Double(cardOffset.width / 20)))
        .offset(cardOffset)
        .gesture(DragGesture(minimumDistance: 15)
            .onChanged { cardOffset = $0.translation }
            .onEnded { value in
                if value.translation.width > 90 { decide(.keep) }
                else if value.translation.width < -90 { decide(.remove) }
                else { withAnimation(.spring) { cardOffset = .zero } }
            })
        .accessibilityLabel("写真。右にスワイプで残す、左にスワイプで削除候補にします")
    }

    private var decisionControls: some View {
        HStack(spacing: 22) {
            Button { decide(.remove) } label: {
                Label("削除候補", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            Button { decide(.keep) } label: {
                Label("残す", systemImage: "heart")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Image(systemName: pendingRemoval.isEmpty ? "checkmark.circle.fill" : "tray.full.fill")
                .font(.system(size: 52))
                .foregroundStyle(pendingRemoval.isEmpty ? .green : .indigo)
            Text(pendingRemoval.isEmpty ? "すべて確認しました" : "削除候補を確認しましょう")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(pendingRemoval.isEmpty ? "写真は変更されていません。" : "\(pendingRemoval.count)件をまとめて確認してから削除できます。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !subscription.isPro { Text("無料版は今月あと \(freeRemaining) 件まで削除できます") .font(.caption).foregroundStyle(.secondary) }
            Button { showConfirmation = true } label: { Label("\(pendingRemoval.count)件を確認して削除", systemImage: "trash") .frame(maxWidth: .infinity).padding(.vertical, 12) }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(pendingRemoval.isEmpty || isDeleting)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
    }

    private func decide(_ decision: Decision) {
        guard let item = current else { return }
        guard decision != .remove || subscription.isPro || pendingRemoval.count < freeRemaining else {
            store.error = "無料版の今月の削除枠に達しました。Photo Cleaner Proなら無制限に整理できます。"
            withAnimation(.spring) { cardOffset = .zero }
            return
        }
        if decision == .remove { pendingRemoval.insert(item.id) }
        history.append(decision)
        withAnimation(.easeInOut(duration: 0.2)) { position += 1; cardOffset = .zero }
    }

    private func undo() {
        guard position > 0, let decision = history.popLast() else { return }
        position -= 1
        if decision == .remove { pendingRemoval.remove(items[position].id) }
    }

    private func removeMarkedItems() {
        let selected = items.filter { pendingRemoval.contains($0.id) }
        Task {
            isDeleting = true
            if await store.delete(selected) {
                if !subscription.isPro { for _ in selected { _ = FreeUsageQuota.consume(namespace: "jp.egawa.roomroll", limit: 30) } }
                dismiss()
            }
            isDeleting = false
        }
    }
}
