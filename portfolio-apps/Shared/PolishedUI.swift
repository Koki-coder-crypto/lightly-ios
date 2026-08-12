import SwiftUI

struct UsageAllowanceCard: View {
    let remaining: Int
    let limit: Int
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("無料枠", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(remaining) / \(limit)")
                    .font(.subheadline.monospacedDigit().weight(.bold))
            }
            ProgressView(value: Double(limit - remaining), total: Double(max(limit, 1)))
                .tint(remaining == 0 ? .orange : .accentColor)
            Button(actionTitle, action: action)
                .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint("この画面の主な操作を開始します")
    }
}
