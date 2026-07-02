import SwiftUI

/// Rankings + player stats behind one tab, split by a segmented control
/// (keeps the tab bar at five items on iPhone).
struct StatsView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case rankings, players
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .rankings: "Rankings"
            case .players: "Players"
            }
        }
    }

    @Environment(\.dataService) private var dataService
    @State private var mode: Mode = .rankings
    @State private var region: Region = .americas
    @State private var timespan: StatsTimespan = .days30
    @State private var rankingsStore: [Region: Loadable<[TeamRanking]>] = [:]
    @State private var statsStore: [String: Loadable<[PlayerStat]>] = [:]
    @State private var search = ""
    @State private var selectedPlayer: PlayerStat?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    content
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Stats")
            .safeAreaInset(edge: .top, spacing: 0) {
                controls
            }
            .searchable(text: $search, prompt: mode == .rankings ? "Search teams" : "Search players")
            .refreshable { await load(force: true) }
            .task(id: taskKey) { await load() }
            .sheet(item: $selectedPlayer) { stat in
                PlayerStatDetail(stat: stat)
                    .presentationDetents([.medium])
            }
        }
    }

    private var taskKey: String {
        "\(mode.rawValue)-\(region.rawValue)-\(timespan.rawValue)"
    }

    private var statsKey: String {
        "\(region.rawValue)-\(timespan.rawValue)"
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Picker("Region", selection: $region) {
                    ForEach(Region.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }
                .pickerStyle(.menu)

                if mode == .players {
                    Picker("Timespan", selection: $timespan) {
                        ForEach(StatsTimespan.allCases) { timespan in
                            Text(timespan.label).tag(timespan)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .rankings:
            rankingsContent
        case .players:
            playersContent
        }
    }

    @ViewBuilder
    private var rankingsContent: some View {
        switch rankingsStore[region] ?? .idle {
        case .idle, .loading:
            SkeletonColumn(count: 8)
        case .failed(let message):
            ErrorRetryView(message: message) { Task { await load(force: true) } }
        case .loaded(let rankings):
            let filtered = search.isEmpty ? rankings : rankings.filter {
                $0.team.name.localizedCaseInsensitiveContains(search) || $0.team.tag.localizedCaseInsensitiveContains(search)
            }
            if filtered.isEmpty {
                EmptyStateView(systemImage: "magnifyingglass",
                               title: "No teams found",
                               message: "No \(region.displayName) team matches \"\(search)\".")
            } else {
                ForEach(filtered) { ranking in
                    RankingRow(ranking: ranking)
                }
            }
        }
    }

    @ViewBuilder
    private var playersContent: some View {
        switch statsStore[statsKey] ?? .idle {
        case .idle, .loading:
            SkeletonColumn(count: 8)
        case .failed(let message):
            ErrorRetryView(message: message) { Task { await load(force: true) } }
        case .loaded(let stats):
            let filtered = search.isEmpty ? stats : stats.filter {
                $0.handle.localizedCaseInsensitiveContains(search) || $0.teamTag.localizedCaseInsensitiveContains(search)
            }
            if filtered.isEmpty {
                EmptyStateView(systemImage: "magnifyingglass",
                               title: "No players found",
                               message: "No \(region.displayName) player matches \"\(search)\".")
            } else {
                ForEach(filtered) { stat in
                    Button {
                        selectedPlayer = stat
                    } label: {
                        PlayerStatRow(stat: stat)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Loading

    private func load(force: Bool = false) async {
        switch mode {
        case .rankings:
            if !force, rankingsStore[region]?.value != nil { return }
            if rankingsStore[region]?.value == nil { rankingsStore[region] = .loading }
            do {
                rankingsStore[region] = .loaded(try await dataService.rankings(region: region))
            } catch {
                if rankingsStore[region]?.value == nil {
                    rankingsStore[region] = .failed(error.localizedDescription)
                }
            }
        case .players:
            let key = statsKey
            if !force, statsStore[key]?.value != nil { return }
            if statsStore[key]?.value == nil { statsStore[key] = .loading }
            do {
                statsStore[key] = .loaded(try await dataService.playerStats(region: region, timespan: timespan))
            } catch {
                if statsStore[key]?.value == nil {
                    statsStore[key] = .failed(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Rows

struct RankingRow: View {
    let ranking: TeamRanking

    var body: some View {
        HStack(spacing: 12) {
            Text("\(ranking.rank)")
                .font(.headline.weight(.black))
                .monospacedDigit()
                .frame(width: 28, alignment: .leading)
            MovementIndicator(movement: ranking.movement)
                .frame(width: 30, alignment: .leading)
            TeamLogoView(team: ranking.team, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(ranking.team.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(ranking.record)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            if let points = ranking.points {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(points)")
                        .font(.subheadline.weight(.black))
                        .monospacedDigit()
                    Text("PTS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            } else if let earnings = ranking.earnings, !earnings.isEmpty {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(earnings)
                        .font(.footnote.weight(.bold))
                        .monospacedDigit()
                    Text("EARNINGS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .cardBackground()
    }
}

struct PlayerStatRow: View {
    let stat: PlayerStat

    var body: some View {
        HStack(spacing: 12) {
            Text(stat.country)
            VStack(alignment: .leading, spacing: 1) {
                Text(stat.handle)
                    .font(.subheadline.weight(.bold))
                Text(stat.teamTag)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statColumn("K/D", String(format: "%.2f", stat.kd))
            statColumn("ACS", String(format: "%.0f", stat.acs))
            VStack(alignment: .trailing, spacing: 0) {
                Text(String(format: "%.2f", stat.rating))
                    .font(.headline.weight(.black))
                    .monospacedDigit()
                Text("RATING")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .cardBackground()
    }

    private func statColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

struct PlayerStatDetail: View {
    let stat: PlayerStat

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Text(stat.country)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.handle)
                        .font(.title2.weight(.black))
                    Text(stat.teamTag)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile("Rating", String(format: "%.2f", stat.rating))
                statTile("ACS", String(format: "%.0f", stat.acs))
                statTile("K/D", String(format: "%.2f", stat.kd))
                statTile("KAST", String(format: "%.0f%%", stat.kast))
                statTile("ADR", String(format: "%.0f", stat.adr))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Top agents")
                HStack(spacing: 6) {
                    ForEach(stat.agents, id: \.self) { agent in
                        AgentChip(name: agent)
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .presentationBackground(Theme.background)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.black))
                .monospacedDigit()
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardBackground()
    }
}
