import SwiftUI

// Events now live as a segment inside `MatchesView`. This file keeps the
// event card + detail screen used from there.

struct EventCard: View {
    let event: VLREvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.region.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.elevated, in: Capsule())
                Spacer()
                if event.status == .ongoing {
                    HStack(spacing: 5) {
                        Circle().fill(Theme.win).frame(width: 6, height: 6)
                        Text("In progress")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(event.name)
                .font(.headline)
                .multilineTextAlignment(.leading)
            if !event.dates.isEmpty || !event.prizePool.isEmpty {
                HStack(spacing: 14) {
                    if !event.dates.isEmpty {
                        Label(event.dates, systemImage: "calendar")
                    }
                    if !event.prizePool.isEmpty {
                        Label(event.prizePool, systemImage: "trophy")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }
}

struct EventDetailView: View {
    let event: VLREvent

    @Environment(\.dataService) private var dataService
    @State private var matches: Loadable<[Match]> = .idle

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                header

                switch matches {
                case .idle, .loading:
                    SkeletonColumn(count: 5)
                case .failed(let message):
                    ErrorRetryView(message: message) { Task { await load(force: true) } }
                case .loaded(let all):
                    if all.isEmpty {
                        EmptyStateView(systemImage: "calendar.badge.clock",
                                       title: "Matches TBA",
                                       message: "The schedule for this event hasn't been posted yet.")
                    } else {
                        ForEach(groupedByStage(all), id: \.stage) { group in
                            SectionHeader(title: group.stage)
                                .padding(.top, 8)
                            ForEach(group.matches) { match in
                                NavigationLink(value: match) { MatchCard(match: match) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(force: true) }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.name)
                .font(.title3.weight(.bold))
            HStack(spacing: 14) {
                if !event.dates.isEmpty {
                    Label(event.dates, systemImage: "calendar")
                }
                if !event.prizePool.isEmpty {
                    Label(event.prizePool, systemImage: "trophy")
                }
                Label(event.region, systemImage: "globe")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardBackground()
    }

    private struct StageGroup {
        let stage: String
        let matches: [Match]
    }

    /// Stage sections in order of most recent activity (live first).
    private func groupedByStage(_ all: [Match]) -> [StageGroup] {
        let ordered = all.sorted { lhs, rhs in
            if (lhs.status == .live) != (rhs.status == .live) { return lhs.status == .live }
            return lhs.time > rhs.time
        }
        var groups: [StageGroup] = []
        var indexByStage: [String: Int] = [:]
        for match in ordered {
            if let index = indexByStage[match.stage] {
                groups[index] = StageGroup(stage: match.stage, matches: groups[index].matches + [match])
            } else {
                indexByStage[match.stage] = groups.count
                groups.append(StageGroup(stage: match.stage, matches: [match]))
            }
        }
        return groups
    }

    private func load(force: Bool = false) async {
        if !force, matches.value != nil { return }
        if matches.value == nil { matches = .loading }
        do {
            matches = .loaded(try await dataService.eventMatches(eventID: event.id))
        } catch {
            if matches.value == nil { matches = .failed(error.localizedDescription) }
        }
    }
}
