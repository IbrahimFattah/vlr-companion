import SwiftUI

struct TeamSelectionView: View {
    @Environment(\.dataService) private var dataService
    @State private var teams: Loadable<[Team]> = .idle
    @State private var search = ""
    @State private var selected: Team?

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
        .navigationTitle("Pick your team")
        .background(Theme.background)
        .searchable(text: $search, prompt: "Search teams")
        .safeAreaInset(edge: .bottom) {
            if let selected {
                NavigationLink {
                    SecondaryTeamsView(favorite: selected)
                } label: {
                    Text("Continue with \(selected.name)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(16)
                .background(.bar)
            }
        }
        .task { await load() }
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
                            TeamPickRow(team: team, isSelected: selected?.id == team.id) {
                                selected = team
                                Haptics.selection()
                            }
                        }
                    }
                }
            }
        }
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

struct TeamPickRow: View {
    let team: Team
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                TeamLogoView(team: team, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(team.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(team.tag) · \(team.region.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.4))
            }
        }
    }
}

struct TeamListSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<10, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle().fill(Theme.elevated).frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 5) {
                        SkeletonBar(width: 140, height: 11)
                        SkeletonBar(width: 80, height: 8)
                    }
                }
                .shimmer()
            }
        }
    }
}
