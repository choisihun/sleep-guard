import SwiftUI

enum SleepRiskLevel: String, Codable, CaseIterable, Identifiable {
    case good
    case caution
    case bad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .good: "정상"
        case .caution: "주의"
        case .bad: "위험"
        }
    }

    var color: Color {
        switch self {
        case .good: .green
        case .caution: .orange
        case .bad: .red
        }
    }
}
