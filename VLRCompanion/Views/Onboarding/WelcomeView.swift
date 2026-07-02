import SwiftUI

struct OnboardingFlow: View {
    @State private var path: [String] = {
        #if DEBUG
        // UI-testing hook: `-vlrShowTeamSelect YES` opens the picker directly.
        UserDefaults.standard.bool(forKey: "vlrShowTeamSelect") ? ["teams"] : []
        #else
        []
        #endif
    }()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView()
                .navigationDestination(for: String.self) { _ in
                    TeamSelectionView()
                }
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("VLR")
                    .font(.system(size: 72, weight: .black))
                    .tracking(4)
                Text("COMPANION")
                    .font(.footnote.weight(.semibold))
                    .tracking(7)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 22) {
                feature("bolt.fill", "Live scores",
                        "An auto-refreshing ticker with map-by-map detail.")
                feature("shield.fill", "Your team, front and center",
                        "Follow one team and get a whole tab in their colors.")
                feature("trophy.fill", "Every event",
                        "VCT schedules, rankings, and player stats in one place.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            NavigationLink {
                TeamSelectionView()
            } label: {
                Text("Choose your team")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)

            Text("One favorite. You can change it anytime.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
        .padding(28)
        .background(Theme.background)
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
