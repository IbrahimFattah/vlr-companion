import SwiftUI

struct RootView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(AccountStore.self) private var account

    var body: some View {
        Group {
            if favorites.onboardingComplete {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: favorites.onboardingComplete)
        // Keep the push worker's picture of who this device follows in sync,
        // so match alerts target the right teams.
        .task {
            await NotificationManager.shared.refreshAuthorizationStatus()
            NotificationManager.shared.updateFollowedTeams(Array(favorites.followedTeamIDs))
            await account.restore()
        }
        .onChange(of: favorites.followedTeamIDs) { _, ids in
            NotificationManager.shared.updateFollowedTeams(Array(ids))
        }
        .onChange(of: favorites.favoriteTeam) { _, _ in syncFavorites() }
        .onChange(of: favorites.secondaryTeams) { _, _ in syncFavorites() }
    }

    /// Mirror local favorites to the account when signed in.
    private func syncFavorites() {
        guard account.isSignedIn else { return }
        Task {
            await account.syncFavorites(favorite: favorites.favoriteTeam?.id,
                                        secondaries: favorites.secondaryTeams.map(\.id))
        }
    }
}
