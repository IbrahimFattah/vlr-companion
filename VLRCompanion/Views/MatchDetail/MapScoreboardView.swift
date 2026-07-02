import SwiftUI

/// Full per-map player scoreboard, vlr.gg style: one table per team, the
/// stat tail scrolls horizontally like the website does on mobile.
struct MapScoreboardView: View {
    let map: MapResult
    let team1: Team
    let team2: Team

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    teamSection(team1, players: map.players1, score: map.score1)
                    teamSection(team2, players: map.players2, score: map.score2)
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle(map.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        let art = MapArt.colors(for: map.name)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(map.name.uppercased())
                    .font(.title3.weight(.black))
                    .tracking(2)
                if map.status == .live {
                    LiveBadge()
                }
            }
            Spacer()
            Text("\(map.score1) – \(map.score2)")
                .font(.system(size: 30, weight: .black))
                .monospacedDigit()
                .foregroundStyle(map.status == .live ? Theme.live : .primary)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [art.0.opacity(0.45), art.1.opacity(0.3)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
        )
    }

    private func teamSection(_ team: Team, players: [MapPlayerStat], score: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TeamLogoView(team: team, size: 26)
                Text(team.name)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(score)")
                    .font(.headline.weight(.black))
                    .monospacedDigit()
            }
            statTable(players)
        }
    }

    // MARK: - Table

    private struct Column {
        let title: String
        let width: CGFloat
        let value: (MapPlayerStat) -> String
    }

    private static let columns: [Column] = [
        Column(title: "R", width: 44) { $0.rating },
        Column(title: "ACS", width: 44) { $0.acs },
        Column(title: "K", width: 30) { $0.kills },
        Column(title: "D", width: 30) { $0.deaths },
        Column(title: "A", width: 30) { $0.assists },
        Column(title: "+/–", width: 40) { $0.kdDiff },
        Column(title: "KAST", width: 48) { $0.kast },
        Column(title: "ADR", width: 44) { $0.adr },
        Column(title: "HS%", width: 44) { $0.hsPercent },
        Column(title: "FK", width: 30) { $0.firstKills },
        Column(title: "FD", width: 30) { $0.firstDeaths },
    ]

    private func statTable(_ players: [MapPlayerStat]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider()
                    .padding(.bottom, 2)
                ForEach(players) { player in
                    row(player)
                }
            }
            .padding(12)
        }
        .cardBackground()
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("PLAYER")
                .frame(width: 126, alignment: .leading)
            ForEach(Self.columns, id: \.title) { column in
                Text(column.title)
                    .frame(width: column.width, alignment: .trailing)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
        .padding(.bottom, 8)
    }

    private func row(_ player: MapPlayerStat) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text(player.agent)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 126, alignment: .leading)

            ForEach(Self.columns, id: \.title) { column in
                let value = column.value(player)
                Text(value)
                    .font(column.title == "R" ? .caption.weight(.black) : .caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(color(for: column.title, value: value))
                    .frame(width: column.width, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }

    /// Kill differential gets the win/loss treatment, like the website.
    private func color(for column: String, value: String) -> Color {
        guard column == "+/–" else { return .primary }
        if value.hasPrefix("+") { return Theme.win }
        if value.hasPrefix("-") { return Theme.loss }
        return .secondary
    }
}
