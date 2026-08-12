import Foundation
import UIKit

@MainActor
final class CompressionStore: ObservableObject {
    enum Preset: String, CaseIterable, Identifiable {
        case share = "共有向け"
        case upload = "アップロード向け"
        case space = "容量を節約"
        var id: String { rawValue }
        var quality: CGFloat { switch self { case .share: 0.82; case .upload: 0.66; case .space: 0.48 } }
        var maximumDimension: CGFloat { switch self { case .share: 2_048; case .upload: 1_600; case .space: 1_280 } }
        var description: String { switch self { case .share: "メッセージやメールで送りやすいサイズ"; case .upload: "フォーム・Webアップロードに便利"; case .space: "ストレージをしっかり節約" } }
    }

    struct Result: Identifiable {
        let id = UUID()
        let url: URL
        let originalBytes: Int
        let compressedBytes: Int
        var saving: Int { max(0, originalBytes - compressedBytes) }
    }

    @Published var preset: Preset = .share
    @Published private(set) var isProcessing = false
    @Published private(set) var results: [Result] = []
    @Published private(set) var processedThisMonth = 0
    @Published var errorMessage: String?

    private let quotaKey = "lightly.freeQuota"
    private let freeMonthlyLimit = 30
    init() { processedThisMonth = UserDefaults.standard.integer(forKey: quotaKey) }
    var freeRemaining: Int { max(0, freeMonthlyLimit - processedThisMonth) }
    var originalTotal: Int { results.reduce(0) { $0 + $1.originalBytes } }
    var compressedTotal: Int { results.reduce(0) { $0 + $1.compressedBytes } }
    var savedTotal: Int { results.reduce(0) { $0 + $1.saving } }
    var savingsPercent: Int { guard originalTotal > 0 else { return 0 }; return Int((Double(savedTotal) / Double(originalTotal) * 100).rounded()) }
    func canProcess(count: Int, isPro: Bool) -> Bool { isPro || count <= freeRemaining }

    func compress(_ data: [Data], isPro: Bool) async {
        guard !data.isEmpty else { return }
        guard canProcess(count: data.count, isPro: isPro) else { errorMessage = "無料プランの今月の処理上限に達しました。Lightly Proなら無制限に処理できます。"; return }
        isProcessing = true; results = []; errorMessage = nil
        defer { isProcessing = false }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Lightly", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var newResults: [Result] = []
            for (index, original) in data.enumerated() {
                guard let source = UIImage(data: original) else { continue }
                let image = source.resized(maximumDimension: preset.maximumDimension)
                guard let compressed = image.jpegData(compressionQuality: preset.quality) else { continue }
                let url = directory.appendingPathComponent("lightly-\(UUID().uuidString)-\(index + 1).jpg")
                try compressed.write(to: url, options: .atomic)
                newResults.append(Result(url: url, originalBytes: original.count, compressedBytes: compressed.count))
            }
            results = newResults
            if !isPro, !newResults.isEmpty { processedThisMonth += newResults.count; UserDefaults.standard.set(processedThisMonth, forKey: quotaKey) }
            if newResults.isEmpty { errorMessage = "処理できる写真が選択されませんでした。別の写真を選んでください。" }
        } catch { errorMessage = "写真を処理できませんでした。もう一度お試しください。" }
    }
    func reset() { results = []; errorMessage = nil }
}

private extension UIImage {
    func resized(maximumDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maximumDimension else { return self }
        let ratio = maximumDimension / longest
        let target = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
