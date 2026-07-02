import SwiftUI

struct MatchDetailView: View {
    let match: Match

    @Environment(\.dataService) private var dataService
    @State private var detail: Loadable<MatchDetail> = .idle

    /// The list row's match, upgraded with detail data (streams, VODs, exact
    /// scores) once it loads.
    private var currentMatch: Match {
        guard let loaded = detail.value?.match else { return match }
        return Match(id: loaded.id,
                     eventName: loaded.eventName.isEmpty ? match.eventName : loaded.eventName,
                     stage: loaded.stage.isEmpty ? match.stage : loaded.stage,
                     team1: loaded.team1,
                     team2: loaded.team2,
                     score1: loaded.score1 ?? match.score1,
                     score2: loaded.score2 ?? match.score2,
                     status: loaded.status == .upcoming && match.status != .upcoming ? match.status : loaded.status,
                     time: match.time,
                     format: loaded.format == .unknown ? match.format : loaded.format,
                     currentMap: loaded.currentMap ?? match.currentMap,
                     streamURL: loaded.streamURL ?? match.streamURL,
                     vodURL: loaded.vodURL ?? match.vodURL)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                watchButtons

                switch detail {
                case .idle, .loading:
                    SkeletonColumn(count: 3)
                case .failed(let message):
                    ErrorRetryView(message: message) { Task { await load(force: true) } }
                case .loaded(let detail):
                    loadedContent(detail)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("\(match.team1.tag) vs \(match.team2.tag)")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(force: true) }
        .task { await load() }
    }

    // MARK: - Hero

    private var hero: some View {
        let shown = currentMatch
        return VStack(spacing: 14) {
            Text([shown.eventName, shown.stage, shown.format.display]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                    .uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 12) {
                heroTeam(shown.team1)
                scoreBlock
                    .frame(maxWidth: .infinity)
                heroTeam(shown.team2)
            }

            if shown.status == .live {
                HStack(spacing: 8) {
                    LiveBadge()
                    if let map = shown.currentMap {
                        Text("Map \((shown.score1 ?? 0) + (shown.score2 ?? 0) + 1) · \(map)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.live)
                    }
                }
            } else if shown.status == .upcoming {
                VStack(spacing: 4) {
                    KickoffLabel(date: shown.time)
                    Text(shown.time, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardBackground()
    }

    private var scoreBlock: some View {
        Group {
            if currentMatch.status == .upcoming {
                Text("VS")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(currentMatch.score1 ?? 0) – \(currentMatch.score2 ?? 0)")
                    .font(.system(size: 40, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(currentMatch.status == .live ? Theme.live : .primary)
            }
        }
    }

    private func heroTeam(_ team: Team) -> some View {
        VStack(spacing: 8) {
            TeamLogoView(team: team, size: 56)
            Text(team.name)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 96)
    }

    // MARK: - Watch links

    @ViewBuilder
    private var watchButtons: some View {
        let match = currentMatch
        HStack(spacing: 10) {
            if match.status == .live, let stream = match.streamURL {
                Link(destination: stream) {
                    Label("Watch live", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.live, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
            }
            if match.status == .upcoming, let stream = match.streamURL {
                Link(destination: stream) {
                    Label("Open stream", systemImage: "play.tv")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if match.status == .completed, let vod = match.vodURL {
                Link(destination: vod) {
                    Label("Watch VOD", systemImage: "play.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - Detail sections

    @ViewBuilder
    private func loadedContent(_ detail: MatchDetail) -> some View {
        if !detail.maps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Maps")
                ForEach(detail.maps) { map in
                    MapCard(map: map, team1: currentMatch.team1, team2: currentMatch.team2)
                }
            }
        }

        if !detail.vetos.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Map veto")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(detail.vetos, id: \.self) { line in
                        HStack(spacing: 8) {
                            Image(systemName: vetoIcon(line))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(line)
                                .font(.callout)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .cardBackground()
            }
        }

        if let headToHead = detail.headToHead {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Head to head")
                Text(headToHead)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .cardBackground()
            }
        }
    }

    private func vetoIcon(_ line: String) -> String {
        if line.contains(" ban ") { return "xmark" }
        if line.contains(" pick ") { return "checkmark" }
        return "flag.checkered"
    }

    private func load(force: Bool = false) async {
        if !force, detail.value != nil { return }
        if detail.value == nil { detail = .loading }
        do {
            detail = .loaded(try await dataService.matchDetail(id: match.id))
        } catch {
            if detail.value == nil { detail = .failed(error.localizedDescription) }
        }
    }
}

// MARK: - Map card

struct MapCard: View {
    let map: MapResult
    let team1: Team
    let team2: Team

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(map.name)
                    .font(.headline)
                if let pickedBy = map.pickedBy {
                    Text(pickedBy == "DECIDER" ? "DECIDER" : "\(pickedBy) PICK")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.elevated, in: Capsule())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailing
            }

            if map.status != .upcoming {
                agentsRow(tag: team1.tag, agents: map.agents1)
                agentsRow(tag: team2.tag, agents: map.agents2)
            }
        }
        .padding(14)
        .cardBackground()
    }

    @ViewBuilder
    private var trailing: some View {
        switch map.status {
        case .upcoming:
            Text("UP NEXT")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
        case .live:
            HStack(spacing: 8) {
                scoreText
                LiveBadge()
            }
        case .completed:
            scoreText
        }
    }

    private var scoreText: some View {
        Text("\(map.score1) – \(map.score2)")
            .font(.headline.weight(.black))
            .monospacedDigit()
            .foregroundStyle(map.status == .live ? Theme.live : .primary)
    }

    @ViewBuilder
    private func agentsRow(tag: String, agents: [String]) -> some View {
        if !agents.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Text(tag)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                    .padding(.top, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(agents, id: \.self) { agent in
                            AgentChip(name: agent)
                        }
                    }
                }
            }
        }
    }
}
