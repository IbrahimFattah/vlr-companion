import Foundation
import Observation

/// The user's favorite team, loosely-followed secondary teams, and onboarding
/// state. Teams are persisted as JSON blobs (not just IDs) so My Team renders
/// offline before any network fetch.
@Observable
final class FavoritesStore {
    private static let favoriteKey = "favoriteTeam"
    private static let secondaryKey = "secondaryTeams"
    private static let onboardingKey = "onboardingComplete"

    static let maxSecondaryTeams = 3

    var favoriteTeam: Team? {
        didSet { Self.save(favoriteTeam, key: Self.favoriteKey) }
    }

    var secondaryTeams: [Team] {
        didSet { Self.save(secondaryTeams, key: Self.secondaryKey) }
    }

    var onboardingComplete: Bool {
        didSet { UserDefaults.standard.set(onboardingComplete, forKey: Self.onboardingKey) }
    }

    init() {
        favoriteTeam = Self.load(Team.self, key: Self.favoriteKey)
        secondaryTeams = Self.load([Team].self, key: Self.secondaryKey) ?? []
        onboardingComplete = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        #if DEBUG
        applyLaunchOverrides()
        #endif
    }

    #if DEBUG
    /// Headless UI-testing hook:
    /// `simctl launch com.vlrcompanion.app -vlrAutofavorite sen`
    /// skips onboarding with the given favorite (plus two sample secondaries).
    private func applyLaunchOverrides() {
        guard let id = UserDefaults.standard.string(forKey: "vlrAutofavorite"),
              let team = MockData.team(id) else { return }
        favoriteTeam = team
        secondaryTeams = ["fnc", "prx", "drx"]
            .compactMap { MockData.team($0) }
            .filter { $0.id != id }
            .prefix(2)
            .map { $0 }
        onboardingComplete = true
    }
    #endif

    /// Favorite plus secondaries — the set that triggers live alerts.
    var followedTeamIDs: Set<String> {
        var ids = Set(secondaryTeams.map(\.id))
        if let favoriteTeam { ids.insert(favoriteTeam.id) }
        return ids
    }

    func isSecondary(_ team: Team) -> Bool {
        secondaryTeams.contains { $0.id == team.id }
    }

    func toggleSecondary(_ team: Team) {
        if let index = secondaryTeams.firstIndex(where: { $0.id == team.id }) {
            secondaryTeams.remove(at: index)
        } else if secondaryTeams.count < Self.maxSecondaryTeams, team.id != favoriteTeam?.id {
            secondaryTeams.append(team)
        }
    }

    func reset() {
        favoriteTeam = nil
        secondaryTeams = []
        onboardingComplete = false
    }

    // MARK: - Persistence

    private static func save<T: Encodable>(_ value: T?, key: String) {
        let defaults = UserDefaults.standard
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
