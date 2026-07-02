import SwiftUI

/// The core match row used across Home, Matches, My Team, and Events.
struct MatchCard: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow)
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                trailingStatus
            }

            VStack(spacing: 8) {
                teamRow(match.team1, score: match.score1, lost: match.status == .completed && match.team2Won)
                teamRow(match.team2, score: match.score2, lost: match.status == .completed && match.team1Won)
            }

            if match.status == .live, let map = match.currentMap {
                Text("Map \((match.score1 ?? 0) + (match.score2 ?? 0) + 1) · \(map)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.live)
            }
        }
        .padding(14)
        .cardBackground()
    }

    private var eyebrow: String {
        "\(match.eventName) · \(match.stage) · \(match.format.display)".uppercased()
    }

    @ViewBuilder
    private var trailingStatus: some View {
        switch match.status {
        case .live:
            LiveBadge()
        case .completed:
            Text("FINAL")
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
        case .upcoming:
            KickoffLabel(date: match.time)
        }
    }

    private func teamRow(_ team: Team, score: Int?, lost: Bool) -> some View {
        HStack(spacing: 10) {
            TeamLogoView(team: team, size: 26)
            Text(team.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let score {
                Text("\(score)")
                    .font(.title3.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(match.status == .live ? Theme.live : .primary)
            }
        }
        .opacity(lost ? 0.5 : 1.0)
    }
}

/// Kickoff time for upcoming matches: a live countdown inside 12 hours,
/// otherwise a compact date.
struct KickoffLabel: View {
    let date: Date

    var body: some View {
        Group {
            if date > .now, date.timeIntervalSinceNow < 12 * 3600 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(timerInterval: Date.now...date, countsDown: true)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            } else if Calendar.current.isDateInToday(date) {
                Text(date, format: .dateTime.hour().minute())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if Calendar.current.isDateInTomorrow(date) {
                Text("Tomorrow \(date, format: .dateTime.hour().minute())")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}
