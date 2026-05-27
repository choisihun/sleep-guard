import SwiftUI

struct AppPickerView: View {
    @ObservedObject var viewModel: ManagedAppsViewModel

    var body: some View {
        SectionCard(title: "배터리 영향 상위 앱") {
            Stepper(value: $viewModel.recommendationLimit, in: 3...20, step: 1) {
                HStack(spacing: 0) {
                    Text("상위 ")
                    Text("\(viewModel.recommendationLimit)")
                        .font(.body.monospacedDigit())
                        .frame(width: 24, alignment: .trailing)
                    Text("개")
                }
            }

            if viewModel.energyRecommendations.isEmpty {
                Text("추천할 실행 앱이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.energyRecommendations.prefix(viewModel.recommendationLimit))) { impact in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(impact.app.displayName)
                                ImpactBadgeView(level: impact.level, score: Int(impact.score.rounded()))
                            }
                            Text(impact.detailText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !impact.reasons.isEmpty {
                                Text(impact.reasons.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            Task { await viewModel.addRecommendation(impact) }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        Button {
                            Task { await viewModel.excludeRecommendation(impact) }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}

private struct ImpactBadgeView: View {
    let level: ManagedAppRiskLevel
    let score: Int

    var body: some View {
        Text("\(level.displayName) \(score)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch level {
        case .high: .red
        case .medium: .orange
        case .low: .green
        }
    }
}
