import SwiftUI

struct RiskBadgeView: View {
    var level: SleepRiskLevel
    var score: Int?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(score.map { "\(level.title) \($0)" } ?? level.title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(level.color.opacity(0.12), in: Capsule())
        .foregroundStyle(level.color)
    }
}
