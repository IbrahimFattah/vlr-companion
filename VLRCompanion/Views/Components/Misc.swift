import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.heavy))
            .tracking(1.4)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ErrorRetryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

/// Win/loss chip shown next to results in My Team.
struct WLChip: View {
    let win: Bool

    var body: some View {
        Text(win ? "W" : "L")
            .font(.caption.weight(.black))
            .foregroundStyle(win ? Theme.win : Theme.loss)
            .frame(width: 24, height: 24)
            .background((win ? Theme.win : Theme.loss).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityLabel(win ? "Won" : "Lost")
    }
}

/// Rank movement since the last update: up, down, or steady.
struct MovementIndicator: View {
    let movement: Int

    var body: some View {
        Group {
            if movement > 0 {
                Label("\(movement)", systemImage: "arrowtriangle.up.fill")
                    .foregroundStyle(Theme.win)
            } else if movement < 0 {
                Label("\(-movement)", systemImage: "arrowtriangle.down.fill")
                    .foregroundStyle(Theme.loss)
            } else {
                Text("–")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
        .accessibilityLabel(movement == 0 ? "No change" : movement > 0 ? "Up \(movement)" : "Down \(-movement)")
    }
}

struct AgentChip: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.elevated, in: Capsule())
    }
}
