import PhotosUI
import SwiftUI
import UIKit

@main
struct HandyPrintApp: App {
    @StateObject private var subscription = SubscriptionManager(monthlyID: "jp.egawa.handyprint.pro.monthly", yearlyID: "jp.egawa.handyprint.pro.yearly")
    var body: some Scene { WindowGroup { PrintHomeView().environmentObject(subscription) } }
}

enum PrintLayout: String, CaseIterable, Identifiable { case full = "写真1枚"; case duo = "2分割"; case four = "4分割"; var id: String { rawValue }; var count: Int { switch self { case .full: 1; case .duo: 2; case .four: 4 } } }

@MainActor
final class PrintStore: ObservableObject {
    @Published var layout: PrintLayout = .full
    @Published var caption = ""
    @Published var images: [UIImage] = []
    @Published var pdfURL: URL?
    @Published var isBuilding = false
    @Published var error: String?
    private let freeNamespace = "jp.egawa.handyprint"
    let freeMonthlyLimit = 3
    var freePDFsRemaining: Int { FreeUsageQuota.remaining(namespace: freeNamespace, limit: freeMonthlyLimit) }
    func makePDF(isPro: Bool) {
        guard !images.isEmpty else { error = "先に写真を選んでください。"; return }
        guard isPro || freePDFsRemaining > 0 else {
            error = "今月の無料PDFは使い切りました。Proなら無制限に作成できます。"
            return
        }
        isBuilding = true; defer { isBuilding = false }
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            context.beginPage()
            let title = "手渡しプリント"
            title.draw(at: CGPoint(x: 40, y: 32), withAttributes: [.font: UIFont.systemFont(ofSize: 20, weight: .bold), .foregroundColor: UIColor.label])
            let text = caption.isEmpty ? "作成日: \(Date.now.formatted(date: .abbreviated, time: .omitted))" : caption
            text.draw(at: CGPoint(x: 40, y: 62), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.secondaryLabel])
            let slots = layout.count
            let gap: CGFloat = 16, width = (page.width - 80 - gap * CGFloat(slots - 1)) / CGFloat(slots)
            for index in 0..<min(slots, images.count) {
                let x = 40 + CGFloat(index) * (width + gap)
                let rect = CGRect(x: x, y: 105, width: width, height: width * 1.25)
                context.cgContext.setFillColor(UIColor.systemGray6.cgColor); context.cgContext.fill(rect)
                images[index].draw(in: aspectFit(images[index], in: rect))
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("handy-print-\(UUID()).pdf")
        do {
            try data.write(to: url)
            if !isPro { _ = FreeUsageQuota.consume(namespace: freeNamespace, limit: freeMonthlyLimit) }
            pdfURL = url
        } catch { self.error = "PDFを作成できませんでした。" }
    }
    private func aspectFit(_ image: UIImage, in rect: CGRect) -> CGRect {
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }
}

struct PrintHomeView: View {
    @StateObject private var store = PrintStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var picks: [PhotosPickerItem] = []
    @State private var showPaywall = false
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) { Label("写真を渡せる1枚に。", systemImage: "printer.fill").font(.system(.title2, design: .rounded, weight: .bold)); Text("レイアウトを選んで、印刷アプリやメッセージへPDFを渡せます。写真は端末内で処理します。").foregroundStyle(.secondary) }
        VStack(alignment: .leading, spacing: 14) { Text("レイアウト").font(.headline); Picker("レイアウト", selection: $store.layout) { ForEach(PrintLayout.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented); TextField("メモ（任意）", text: $store.caption).textFieldStyle(.roundedBorder) }.cardStyle()
        PhotosPicker(selection: $picks, maxSelectionCount: 4, matching: .images) { Label(store.images.isEmpty ? "写真を選ぶ" : "写真を選び直す（\(store.images.count)枚）", systemImage: "photo.on.rectangle.angled") .frame(maxWidth: .infinity).padding(8) }.buttonStyle(.borderedProminent).onChange(of: picks) { _, selected in Task { var result: [UIImage] = []; for pick in selected { if let data = try? await pick.loadTransferable(type: Data.self), let image = UIImage(data: data) { result.append(image) } }; store.images = result } }
        if !store.images.isEmpty { HStack { ForEach(Array(store.images.enumerated()), id: \.offset) { _, image in Image(uiImage: image).resizable().scaledToFill().frame(width: 72, height: 92).clipShape(RoundedRectangle(cornerRadius: 10)) }; Spacer() }.padding(.vertical, 4) }
        if !subscription.isPro { Text("無料枠: 今月あと \(store.freePDFsRemaining)/\(store.freeMonthlyLimit) 枚").font(.caption).foregroundStyle(.secondary) }
        Button { store.makePDF(isPro: subscription.isPro) } label: { Label("印刷用PDFを作る", systemImage: "doc.fill") .frame(maxWidth: .infinity).padding(8) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.isBuilding)
        if let url = store.pdfURL { VStack(alignment: .leading, spacing: 10) { Label("PDFを作成しました", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline); ShareLink(item: url) { Label("印刷アプリ・メッセージへ共有", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered) }.cardStyle() }
        if !subscription.isPro { Button("Proで無制限のPDF作成へ") { showPaywall = true }.frame(maxWidth: .infinity) }
    }.padding(20) }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("手渡しプリント").sheet(isPresented: $showPaywall) { SubscriptionPaywall(name: "手渡しプリント", benefits: ["無制限のPDF作成", "1・2・4写真レイアウト", "端末内でのPDF生成"], privacyURL: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/portfolio/privacy.html")!) }.alert("お知らせ", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(store.error ?? "") } } }
}

private extension View { func cardStyle() -> some View { padding(18).background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous)) } }
