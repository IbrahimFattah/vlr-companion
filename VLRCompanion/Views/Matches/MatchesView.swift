import SwiftUI

struct MatchesView: View {
    @Environment(\.dataService) private var dataService
    @State private var query: MatchQuery = .live
    @State private var store: [MatchQuery: Loadable<[Match]>] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Matches")
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Match filter", selection: $query) {
                    ForEach(MatchQuery.allCases) { query in
                        Text(query.displayName).tag(query)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationDestination(for: Match.self) { MatchDetailView(match: $0) }
            .refreshable { await load(query, force: true) }
            .task(id: query) { await load(query) }
        }
    }

    private var current: Loadable<[Match]> {
        store[query] ?? .idle
    }

    @ViewBuilder
    private var content: some View {
        switch current {
        case .idle, .loading:
            SkeletonColumn(count: 6)
        case .failed(let message):
            ErrorRetryView(message: message) { Task { await load(query, force: true) } }
        case .loaded(let matches):
            if matches.isEmpty {
                emptyState
            } else if query == .live {
                ForEach(matches) { match in
                    NavigationLink(value: match) { MatchCard(match: match) }
                        .buttonStyle(.plain)
                }
            } else {
                ForEach(groupedByDay(matches), id: \.title) { group in
                    SectionHeader(title: group.title)
                        .padding(.top, 6)
                    ForEach(group.matches) { match in
                        NavigationLink(value: match) { MatchCard(match: match) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        switch query {
        case .live:
            EmptyStateView(systemImage: "moon.zzz",
                           title: "No live matches",
                           message: "Nothing is on right now. Check Upcoming for the next games.")
        case .upcoming:
            EmptyStateView(systemImage: "calendar.badge.clock",
                           title: "Nothing scheduled",
                           message: "No upcoming matches found. Pull to refresh.")
        case .results:
            EmptyStateView(systemImage: "flag.checkered",
                           title: "No results yet",
                           message: "Completed matches will show up here.")
        }
    }

    private struct DayGroup {
        let title: String
        let matches: [Match]
    }

    private func groupedByDay(_ matches: [Match]) -> [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []
        var bucket: [Date: Int] = [:]

        for match in matches {
            let day = calendar.startOfDay(for: match.time)
            if let index = bucket[day] {
                groups[index] = DayGroup(title: groups[index].title, matches: groups[index].matches + [match])
            } else {
                bucket[day] = groups.count
                groups.append(DayGroup(title: dayTitle(day), matches: [match]))
            }
        }
        return groups
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func load(_ query: MatchQuery, force: Bool = false) async {
        if !force, store[query]?.value != nil { return }
        if store[query]?.value == nil { store[query] = .loading }
        do {
            store[query] = .loaded(try await dataService.matches(query))
        } catch {
            if store[query]?.value == nil {
                store[query] = .failed(error.localizedDescription)
            }
        }
    }
}
