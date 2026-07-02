import SwiftUI

struct LiveBadge: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.live)
                .frame(width: 7, height: 7)
                .scaleEffect(pulsing ? 1.0 : 0.6)
                .opacity(pulsing ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulsing)
            Text("LIVE")
                .font(.caption2.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Theme.live)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.live.opacity(0.12), in: Capsule())
        .onAppear { pulsing = true }
        .accessibilityLabel("Live now")
    }
}
