import SwiftUI

struct RootView: View {
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        Group {
            if favorites.onboardingComplete {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: favorites.onboardingComplete)
    }
}
