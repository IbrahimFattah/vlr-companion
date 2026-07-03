import SwiftUI

/// Matches + Events in one tab. The top segment picks Live / Upcoming / Results
/// (match lists) or Events (tournament list with its own status sub-filter).
struct MatchesView: View {
    @Environment(\.dataService) private var dataService

    enum Segment: Hashable, CaseIterable, Identifiable {
        case live, upcoming, results, events
        var id: Self { self }
        var title: String {
            switch self {
            case .live: "Live"
            case .upcoming: "Upcoming"
            case .results: "Results"
            case .events: "Events"
            }
        }
        var matchQuery: MatchQuery? {
            switch self {
            case .live: .live
            case .upcoming: .upcoming
            case .results: .results
            case .events: nil
            }
        }
    }

    @State private var segment: Segment = .live
    @State private var matchStore: [MatchQuery: Loadable<[Match]>] = [:]
    @State private var eventStatus: EventStatus = .ongoing
    @State private var eventStore: [EventStatus: Loadable<[VLREvent]>] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if segment == .events { eventsContent } else { matchesContent }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle(segment == .events ? "Events" : "Matches")
            .safeAreaInset(edge: .top, spacing: 0) { filterBar }
            .navigationDestination(for: Match.self) { MatchDetailView(match: $0) }
            .navigationDestination(for: VLREvent.self) { EventDetailView(event: $0) }
            .refreshable { await reload(force: true) }
            .task(id: segment) { await reload() }
            .task(id: eventStatus) { if segment == .events { await loadEvents(eventStatus) } }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            Picker("Section", selection: $segment) {
                ForEach(Segment.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if segment == .events {
                Picker("Event filter", selection: $eventStatus) {
                    ForEach(EventStatus.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Matches

    @ViewBuilder
    private var matchesContent: some View {
        let query = segment.matchQuery ?? .live
        switch matchStore[query] ?? .idle {
        case .idle, .loading:
            SkeletonColumn(count: 6)
        case .failed(let message):
            ErrorRetryView(message: message) { Task { await loadMatches(query, force: true) } }
        case .loaded(let matches):
            if matches.isEmpty {
                matchEmptyState(query)
            } else if query == .live {
                ForEach(matches) { match in
                    NavigationLink(value: match) { MatchCard(match: match) }.buttonStyle(.plain)
                }
            } else {
                ForEach(groupedByDay(matches), id: \.title) { group in
                    SectionHeader(title: group.title).padding(.top, 6)
                    ForEach(group.matches) { match in
                        NavigationLink(value: match) { MatchCard(match: match) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func matchEmptyState(_ query: MatchQuery) -> some View {
        switch query {
        case .live:
            EmptyStateView(systemImage: "moon.zzz", title: "No live matches",
                           message: "Nothing is on right now. Check Upcoming for the next games.")
        case .upcoming:
            EmptyStateView(systemImage: "calendar.badge.clock", title: "Nothing scheduled",
                           message: "No upcoming matches found. Pull to refresh.")
        case .results:
            EmptyStateView(systemImage: "flag.checkered", title: "No results yet",
                           message: "Completed matches will show up here.")
        }
    }

    // MARK: - Events

    @ViewBuilder
    private var eventsContent: some View {
        switch eventStore[eventStatus] ?? .idle {
        case .idle, .loading:
            SkeletonColumn(count: 5)
        case .failed(let message):
            ErrorRetryView(message: message) { Task { await loadEvents(eventStatus, force: true) } }
        case .loaded(let events):
            if events.isEmpty {
                EmptyStateView(systemImage: "trophy",
                               title: "No \(eventStatus.displayName.lowercased()) events",
                               message: "Pull to refresh, or check another filter.")
            } else {
                ForEach(events) { event in
                    NavigationLink(value: event) { EventCard(event: event) }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Loading

    private func reload(force: Bool = false) async {
        if let query = segment.matchQuery {
            await loadMatches(query, force: force)
        } else {
            await loadEvents(eventStatus, force: force)
        }
    }

    private func loadMatches(_ query: MatchQuery, force: Bool = false) async {
        if !force, matchStore[query]?.value != nil { return }
        if matchStore[query]?.value == nil { matchStore[query] = .loading }
        do {
            matchStore[query] = .loaded(try await dataService.matches(query))
        } catch {
            if matchStore[query]?.value == nil { matchStore[query] = .failed(error.localizedDescription) }
        }
    }

    private func loadEvents(_ status: EventStatus, force: Bool = false) async {
        if !force, eventStore[status]?.value != nil { return }
        if eventStore[status]?.value == nil { eventStore[status] = .loading }
        do {
            eventStore[status] = .loaded(try await dataService.events(status))
        } catch {
            if eventStore[status]?.value == nil { eventStore[status] = .failed(error.localizedDescription) }
        }
    }

    // MARK: - Day grouping

    private struct DayGroup { let title: String; let matches: [Match] }

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
}
