import SwiftUI

struct SleepGuardIcon: View {
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Sleep Guard")
    }
}
