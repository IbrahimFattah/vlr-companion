import SwiftUI

struct HomeView: View {
    @Environment(\.dataService) private var dataService
    @Environment(FavoritesStore.self) private var favorites
    @Environment(PushRouter.self) private var pushRouter

    @State private var live: Loadable<[Match]> = .idle
    @State private var upcoming: Loadable<[Match]> = .idle
    @State private var results: Loadable<[Match]> = .idle
    @State private var news: Loadable<[NewsItem]> = .idle
    /// Live match IDs from the previous tick; nil until the first load so we
    /// don't fire alerts for matches that were already live at launch.
    @State private var knownLiveIDs: Set<String>?
    @State private var showSettings = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    liveSection
                    upNextSection
                    resultsSection
                    newsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .navigationTitle("VLR Companion")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: Match.self) { MatchDetailView(match: $0) }
            .navigationDestination(for: DiscussionRoute.self) { DiscussionScreen(route: $0) }
            .refreshable { await refresh() }
            .task { await autoRefresh() }
            .onAppear { consumePendingRoute() }
            .onChange(of: pushRouter.pendingMatch) { _, _ in consumePendingRoute() }
        }
    }

    /// Pushes the match a tapped notification wants to open, then clears it so
    /// it doesn't re-navigate on the next state change.
    private func consumePendingRoute() {
        guard let match = pushRouter.pendingMatch else { return }
        path.append(match)
        pushRouter.pendingMatch = nil
    }

    // MARK: - Sections

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Live now")
            switch live {
            case .idle, .loading:
                SkeletonColumn(count: 2)
            case .failed(let message):
                ErrorRetryView(message: message) { Task { await refresh() } }
            case .loaded(let matches):
                if matches.isEmpty {
                    Text("No live matches right now — next games below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .cardBackground()
                } else {
                    ForEach(matches) { match in
                        NavigationLink(value: match) { MatchCard(match: match) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch upcoming {
            case .idle, .loading:
                SectionHeader(title: "Today")
                SkeletonColumn(count: 2)
            case .failed:
                EmptyView()
            case .loaded(let matches):
                let todays = matches.filter { Calendar.current.isDateInToday($0.time) }
                let shown = todays.isEmpty ? Array(matches.prefix(3)) : Array(todays.prefix(6))
                SectionHeader(title: todays.isEmpty ? "Up next" : "Today")
                ForEach(shown) { match in
                    NavigationLink(value: match) { MatchCard(match: match) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent results")
            switch results {
            case .idle, .loading:
                SkeletonColumn(count: 3)
            case .failed:
                EmptyView()
            case .loaded(let matches):
                ForEach(matches.prefix(5)) { match in
                    NavigationLink(value: match) { MatchCard(match: match) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Headlines")
            switch news {
            case .idle, .loading:
                SkeletonColumn(count: 2)
            case .failed:
                EmptyView()
            case .loaded(let items):
                ForEach(items) { item in
                    if let url = item.url {
                        Link(destination: url) { NewsRow(item: item) }
                            .buttonStyle(.plain)
                    } else {
                        NewsRow(item: item)
                    }
                }
            }
        }
    }

    // MARK: - Loading

    /// Initial load plus a 30-second live ticker; cancelled automatically
    /// when the tab disappears.
    private func autoRefresh() async {
        var firstPass = true
        while !Task.isCancelled {
            await refresh()
            if firstPass {
                firstPass = false
                #if DEBUG
                openMatchFromLaunchArguments()
                #endif
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }

    #if DEBUG
    /// UI-testing hooks after the first load:
    /// - `-vlrOpenMatch <id>` pushes that match's detail directly.
    /// - `-vlrPushMatch <id>` simulates tapping a push for that match: it builds
    ///   the real APNs payload, runs it through `Match.fromPushPayload`, and
    ///   routes via `PushRouter` — exercising the whole notification-tap path.
    private func openMatchFromLaunchArguments() {
        let pools = [live.value, upcoming.value, results.value]
        if let id = UserDefaults.standard.string(forKey: "vlrOpenMatch"),
           let match = pools.compactMap({ $0?.first { $0.id == id } }).first {
            path.append(match)
        }
        if let ref = UserDefaults.standard.string(forKey: "vlrOpenDiscussion") {
            path.append(DiscussionRoute(scope: "match", ref: ref, title: "Match chat"))
        }
        if let id = UserDefaults.standard.string(forKey: "vlrPushMatch"),
           let match = pools.compactMap({ $0?.first { $0.id == id } }).first {
            pushRouter.handle(userInfo: ["match": [
                "id": match.id,
                "team1": match.team1.name, "tag1": match.team1.tag, "color1": match.team1.colorHex,
                "team2": match.team2.name, "tag2": match.team2.tag, "color2": match.team2.colorHex,
                "event": match.eventName, "stage": match.stage, "status": match.status.rawValue,
            ]])
        }
    }
    #endif

    private func refresh() async {
        if live.value == nil {
            live = .loading
            upcoming = .loading
            results = .loading
            news = .loading
        }

        let service = dataService
        let liveTask = Task { try await service.matches(.live) }
        let upcomingTask = Task { try await service.matches(.upcoming) }
        let resultsTask = Task { try await service.matches(.results) }
        let newsTask = Task { try await service.news() }

        switch await liveTask.result {
        case .success(let matches):
            announceNewLiveMatches(matches)
            live = .loaded(matches)
        case .failure(let error):
            if live.value == nil { live = .failed(error.localizedDescription) }
        }
        if let value = try? await upcomingTask.value { upcoming = .loaded(value) }
        else if upcoming.value == nil { upcoming = .failed("Couldn't load matches.") }
        if let value = try? await resultsTask.value { results = .loaded(value) }
        else if results.value == nil { results = .failed("Couldn't load results.") }
        if let value = try? await newsTask.value { news = .loaded(value) }
        else if news.value == nil { news = .failed("Couldn't load news.") }
    }

    /// Haptic + local notification when a followed team's match flips live.
    private func announceNewLiveMatches(_ matches: [Match]) {
        let ids = Set(matches.map(\.id))
        defer { knownLiveIDs = ids }
        guard let known = knownLiveIDs else { return }

        let followed = favorites.followedTeamIDs
        for match in matches where !known.contains(match.id) {
            if followed.contains(match.team1.id) || followed.contains(match.team2.id) {
                Haptics.liveAlert()
                NotificationManager.shared.notifyMatchLive(match)
            }
        }
    }
}

struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
            Text(item.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(item.author) · \(item.date, format: .relative(presentation: .named))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }
}
