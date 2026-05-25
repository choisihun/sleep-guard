import SwiftUI

struct BatteryStatusView: View {
    var info: BatteryInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(info.powerSource == .battery ? .orange : .green)
            Text("\(info.percent)%")
                .font(.headline)
            Text(info.powerSource.displayName)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        if info.isCharging { return "battery.100percent.bolt" }
        switch info.percent {
        case 80...100: return "battery.100percent"
        case 50..<80: return "battery.75percent"
        case 20..<50: return "battery.25percent"
        default: return "battery.0percent"
        }
    }
}
