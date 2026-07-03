import SwiftUI

enum AppTab: Hashable {
    case home, matches, myTeam, community, stats
}

struct MainTabView: View {
    @Environment(PushRouter.self) private var pushRouter
    @State private var selection: AppTab = .home

    init() {
        #if DEBUG
        // UI-testing hook: `-vlrInitialTab matches|myteam|events|stats`
        if let raw = UserDefaults.standard.string(forKey: "vlrInitialTab") {
            let tab: AppTab
            switch raw {
            case "matches", "events": tab = .matches   // events folded into Matches
            case "myteam": tab = .myTeam
            case "community": tab = .community
            case "stats": tab = .stats
            default: tab = .home
            }
            _selection = State(initialValue: tab)
        }
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            MatchesView()
                .tabItem { Label("Matches", systemImage: "flag.2.crossed.fill") }
                .tag(AppTab.matches)

            MyTeamView()
                .tabItem { Label("My Team", systemImage: "shield.fill") }
                .tag(AppTab.myTeam)

            CommunityView()
                .tabItem { Label("Community", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.community)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(AppTab.stats)
        }
        // A tapped push routes through Home's navigation stack, so bring Home
        // forward before it consumes the pending match.
        .onChange(of: pushRouter.pendingMatch) { _, match in
            if match != nil { selection = .home }
        }
    }
}
