import SwiftUI

enum AppTab: Hashable {
    case home, matches, myTeam, events, stats
}

struct MainTabView: View {
    @State private var selection: AppTab = .home

    init() {
        #if DEBUG
        // UI-testing hook: `-vlrInitialTab matches|myteam|events|stats`
        if let raw = UserDefaults.standard.string(forKey: "vlrInitialTab") {
            let tab: AppTab
            switch raw {
            case "matches": tab = .matches
            case "myteam": tab = .myTeam
            case "events": tab = .events
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

            EventsView()
                .tabItem { Label("Events", systemImage: "trophy.fill") }
                .tag(AppTab.events)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(AppTab.stats)
        }
    }
}
