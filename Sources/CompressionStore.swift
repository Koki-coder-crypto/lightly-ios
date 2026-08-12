import Foundation
import UIKit

@MainActor
final class CompressionStore: ObservableObject {
    enum Preset: String, CaseIterable, Identifiable {
        case gentle = "きれい"
        case balanced = "おすすめ"
        case compact = "最小"
        var id: String { rawValue }
        var quality: CGFloat {
            switch self { case .gentle: 0.88; case .balanced: 0.68; case .compact: 0.42 }
        }
        var maximumDimension: CGFloat {
            switch self { case .gentle: 2400; case .balanced: 1800; case .compact: 1280 }
        }
    }

    struct Result: Identifiable {
        let id = UUID()
        let url: URL
        let originalBytes: Int
        let compressedBytes: Int
        var saving: Int { max(0, originalBytes - compressedBytes) }
    }

    @Published var preset: Preset = .balanced
    @Published private(set) var isProcessing = false
    @Published private(set) var results: [Result] = []
    @Published var errorMessage: String?

    private let quotaKey = "lightly.freeQuota"
    private var quotaPeriod: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: .now)
    }

    var freeRemaining: Int {
        let stored = UserDefaults.standard.dictionary(forKey: quotaKey) as? [String: Int] ?? [:]
        return max(0, 30 - (stored[quotaPeriod] ?? 0))
    }

    func canProcess(count: Int, isPro: Bool) -> Bool { isPro || count <= freeRemaining }

    var originalTotal: Int { results.reduce(0) { $0 + $1.originalBytes } }
    var compressedTotal: Int { results.reduce(0) { $0 + $1.compressedBytes } }
    var savedTotal: Int { results.reduce(0) { $0 + $1.saving } }

    func compress(_ data: [Data], isPro: Bool) async {
        guard !data.isEmpty else { return }
        guard canProcess(count: data.count, isPro: isPro) else {
            errorMessage = "無料版は月30枚までです。Proにすると無制限で軽量化できます。"
            return
        }
        isProcessing = true
        results = []
        errorMessage = nil
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
            if !isPro, !newResults.isEmpty {
                var stored = UserDefaults.standard.dictionary(forKey: quotaKey) as? [String: Int] ?? [:]
                stored[quotaPeriod, default: 0] += newResults.count
                UserDefaults.standard.set(stored, forKey: quotaKey)
            }
            if newResults.isEmpty { errorMessage = "対応している画像を読み込めませんでした。" }
        } catch {
            errorMessage = "軽量化できませんでした。もう一度お試しください。"
        }
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
