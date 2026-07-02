import SwiftUI

struct MatchDetailView: View {
    let match: Match

    @Environment(\.dataService) private var dataService
    @State private var detail: Loadable<MatchDetail> = .idle

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
        VStack(spacing: 14) {
            Text("\(match.eventName) · \(match.stage) · \(match.format.display)".uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 12) {
                heroTeam(match.team1)
                scoreBlock
                    .frame(maxWidth: .infinity)
                heroTeam(match.team2)
            }

            if match.status == .live {
                HStack(spacing: 8) {
                    LiveBadge()
                    if let map = match.currentMap {
                        Text("Map \((match.score1 ?? 0) + (match.score2 ?? 0) + 1) · \(map)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.live)
                    }
                }
            } else if match.status == .upcoming {
                VStack(spacing: 4) {
                    KickoffLabel(date: match.time)
                    Text(match.time, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
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
            if match.status == .upcoming {
                Text("VS")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(match.score1 ?? 0) – \(match.score2 ?? 0)")
                    .font(.system(size: 40, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(match.status == .live ? Theme.live : .primary)
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
                    MapCard(map: map, team1: match.team1, team2: match.team2)
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
                    Text("\(pickedBy) PICK")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.elevated, in: Capsule())
                        .foregroundStyle(.secondary)
                } else if map.status != .upcoming || map.pickedBy == nil {
                    Text("DECIDER")
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
