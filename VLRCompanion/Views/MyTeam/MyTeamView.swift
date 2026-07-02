import SwiftUI

/// The personalized tab: everything about the user's favorite team, tinted
/// with the team's brand color.
struct MyTeamView: View {
    @Environment(\.dataService) private var dataService
    @Environment(FavoritesStore.self) private var favorites

    @State private var profile: Loadable<TeamProfile> = .idle
    /// A secondary team being previewed; nil means the favorite.
    @State private var displayedTeam: Team?
    @State private var showTeamPicker = false

    private var team: Team? {
        displayedTeam ?? favorites.favoriteTeam
    }

    var body: some View {
        NavigationStack {
            Group {
                if let team {
                    content(team)
                        .tint(Color(hex: team.colorHex))
                } else {
                    noTeamState
                }
            }
            .background(Theme.background)
            .navigationTitle(team?.name ?? "My Team")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Change team") { showTeamPicker = true }
                        .font(.subheadline)
                }
            }
            .sheet(isPresented: $showTeamPicker) { TeamPickerSheet() }
            .navigationDestination(for: Match.self) { MatchDetailView(match: $0) }
            .onChange(of: favorites.favoriteTeam) { displayedTeam = nil }
        }
    }

    private var noTeamState: some View {
        VStack(spacing: 16) {
            EmptyStateView(systemImage: "shield.slash",
                           title: "No favorite team yet",
                           message: "Pick a team to unlock this tab: schedule, results, roster, and standings in their colors.")
            Button("Pick a team") { showTeamPicker = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    private func content(_ team: Team) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                header(team)
                followingStrip
                switch profile {
                case .idle, .loading:
                    SkeletonColumn(count: 4)
                case .failed(let message):
                    ErrorRetryView(message: message) { Task { await load(team, force: true) } }
                case .loaded(let profile):
                    loadedContent(profile)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable { await load(team, force: true) }
        .task(id: team.id) { await load(team) }
    }

    // MARK: - Header

    private func header(_ team: Team) -> some View {
        let color = Color(hex: team.colorHex)
        return HStack(spacing: 16) {
            TeamLogoView(team: team, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(team.tag)
                    .font(.title2.weight(.black))
                    .tracking(1.5)
                HStack(spacing: 6) {
                    Text(team.region.displayName)
                    if let ranking = profile.value?.ranking {
                        Text("·")
                        Text("#\(ranking) \(team.region.displayName)")
                    }
                    if let record = profile.value?.record {
                        Text("·")
                        Text(record).monospacedDigit()
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.22), Theme.surface],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    @ViewBuilder
    private var followingStrip: some View {
        if !favorites.secondaryTeams.isEmpty, let favorite = favorites.favoriteTeam {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([favorite] + favorites.secondaryTeams) { option in
                        followChip(option, isCurrent: option.id == team?.id)
                    }
                }
            }
        }
    }

    private func followChip(_ option: Team, isCurrent: Bool) -> some View {
        Button {
            displayedTeam = option.id == favorites.favoriteTeam?.id ? nil : option
            Haptics.selection()
        } label: {
            HStack(spacing: 6) {
                TeamLogoView(team: option, size: 20)
                Text(option.tag)
                    .font(.caption.weight(.bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isCurrent ? Theme.elevated : Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isCurrent ? Color(hex: option.colorHex).opacity(0.6) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loaded content

    @ViewBuilder
    private func loadedContent(_ profile: TeamProfile) -> some View {
        if let next = profile.upcoming.first {
            NavigationLink(value: next) {
                NextMatchHero(match: next, teamColor: Color(hex: profile.team.colorHex))
            }
            .buttonStyle(.plain)
        }

        let laterMatches = Array(profile.upcoming.dropFirst().prefix(3))
        if !laterMatches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Upcoming")
                ForEach(laterMatches) { match in
                    NavigationLink(value: match) { MatchCard(match: match) }
                        .buttonStyle(.plain)
                }
            }
        }

        if !profile.results.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Recent results")
                ForEach(profile.results.prefix(8)) { match in
                    NavigationLink(value: match) {
                        ResultRow(match: match, teamID: profile.team.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Roster")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(profile.roster) { player in
                    PlayerCard(player: player)
                }
            }
            ForEach(profile.staff) { player in
                PlayerCard(player: player)
            }
        }

        if let standing = profile.standing {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Standing")
                VStack(alignment: .leading, spacing: 6) {
                    Text(standing)
                        .font(.subheadline.weight(.semibold))
                    if let record = profile.record {
                        Text("Map record \(record)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .cardBackground()
            }
        }
    }

    private func load(_ team: Team, force: Bool = false) async {
        if !force, profile.value?.team.id == team.id { return }
        if profile.value?.team.id != team.id { profile = .loading }
        do {
            profile = .loaded(try await dataService.teamProfile(id: team.id))
        } catch {
            if profile.value == nil { profile = .failed(error.localizedDescription) }
        }
    }
}

// MARK: - Pieces

/// Big spotlight card for the team's next (or currently live) match.
struct NextMatchHero: View {
    let match: Match
    let teamColor: Color

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(match.status == .live ? "ON NOW" : "NEXT MATCH")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
                if match.status == .live {
                    LiveBadge()
                } else {
                    KickoffLabel(date: match.time)
                }
            }

            HStack(spacing: 24) {
                heroTeam(match.team1)
                Text(centerText)
                    .font(.system(size: 34, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(match.status == .live ? Theme.live : .primary)
                heroTeam(match.team2)
            }
            .frame(maxWidth: .infinity)

            Text([match.eventName, match.stage, match.format.display]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .strokeBorder(teamColor.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var centerText: String {
        if let score1 = match.score1, let score2 = match.score2, match.status != .upcoming {
            return "\(score1)–\(score2)"
        }
        return "VS"
    }

    private func heroTeam(_ team: Team) -> some View {
        VStack(spacing: 8) {
            TeamLogoView(team: team, size: 52)
            Text(team.tag)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Compact result line: W/L chip, opponent, score, date.
struct ResultRow: View {
    let match: Match
    let teamID: String

    var body: some View {
        HStack(spacing: 12) {
            if let win = match.didWin(teamID) {
                WLChip(win: win)
            }
            if let opponent = match.opponent(of: teamID) {
                TeamLogoView(team: opponent, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("vs \(opponent.name)")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(match.eventName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(scoreText)
                    .font(.subheadline.weight(.black))
                    .monospacedDigit()
                Text(match.time, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .cardBackground()
    }

    private var scoreText: String {
        let mine = match.team1.id == teamID ? match.score1 : match.score2
        let theirs = match.team1.id == teamID ? match.score2 : match.score1
        return "\(mine ?? 0)–\(theirs ?? 0)"
    }
}

struct PlayerCard: View {
    let player: Player

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(player.country)
                Text(player.handle)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }
            Text(player.realName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let role = player.role {
                Text(role.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground()
    }
}

/// Change-favorite sheet, shared by My Team and Settings.
struct TeamPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dataService) private var dataService
    @Environment(FavoritesStore.self) private var favorites

    @State private var teams: Loadable<[Team]> = .idle
    @State private var search = ""

    var body: some View {
        NavigationStack {
            Group {
                switch teams {
                case .idle, .loading:
                    TeamListSkeleton()
                case .failed(let message):
                    ErrorRetryView(message: message) { Task { await load() } }
                case .loaded(let all):
                    teamList(all)
                }
            }
            .navigationTitle("Choose favorite")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search teams")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func teamList(_ all: [Team]) -> some View {
        let filtered = search.isEmpty ? all : all.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.tag.localizedCaseInsensitiveContains(search)
        }
        return List {
            ForEach(Region.allCases) { region in
                let regionTeams = filtered.filter { $0.region == region }
                if !regionTeams.isEmpty {
                    Section(region.displayName) {
                        ForEach(regionTeams) { team in
                            TeamPickRow(team: team, isSelected: favorites.favoriteTeam?.id == team.id) {
                                select(team)
                            }
                        }
                    }
                }
            }
        }
    }

    private func select(_ team: Team) {
        favorites.favoriteTeam = team
        favorites.secondaryTeams.removeAll { $0.id == team.id }
        Haptics.selection()
        dismiss()
    }

    private func load() async {
        teams = .loading
        do {
            teams = .loaded(try await dataService.allTeams())
        } catch {
            teams = .failed(error.localizedDescription)
        }
    }
}
