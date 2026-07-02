import SwiftUI

/// Optional second onboarding step: follow up to three more teams loosely.
struct SecondaryTeamsView: View {
    let favorite: Team

    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.dataService) private var dataService
    @State private var teams: Loadable<[Team]> = .idle
    @State private var selected: [Team] = []

    var body: some View {
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
        .navigationTitle("Follow a few more?")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") { finish(with: []) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                finish(with: selected)
            } label: {
                Text(selected.isEmpty ? "Finish" : "Finish · following \(selected.count + 1) teams")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(16)
            .background(.bar)
        }
        .task { await load() }
    }

    private func teamList(_ all: [Team]) -> some View {
        List {
            Section {
                Text("Pick up to \(FavoritesStore.maxSecondaryTeams) teams to keep an eye on. They get live alerts too, without taking over the My Team tab.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(Region.allCases) { region in
                let regionTeams = all.filter { $0.region == region && $0.id != favorite.id }
                if !regionTeams.isEmpty {
                    Section(region.displayName) {
                        ForEach(regionTeams) { team in
                            TeamPickRow(team: team, isSelected: isSelected(team)) {
                                toggle(team)
                            }
                            .disabled(!isSelected(team) && selected.count >= FavoritesStore.maxSecondaryTeams)
                        }
                    }
                }
            }
        }
    }

    private func isSelected(_ team: Team) -> Bool {
        selected.contains { $0.id == team.id }
    }

    private func toggle(_ team: Team) {
        if let index = selected.firstIndex(where: { $0.id == team.id }) {
            selected.remove(at: index)
        } else if selected.count < FavoritesStore.maxSecondaryTeams {
            selected.append(team)
        }
        Haptics.selection()
    }

    private func finish(with secondaries: [Team]) {
        favorites.favoriteTeam = favorite
        favorites.secondaryTeams = secondaries
        Task { await NotificationManager.shared.enableNotifications() }
        favorites.onboardingComplete = true
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
