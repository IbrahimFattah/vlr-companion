import Foundation

/// Active data source during UI testing. Serves the deterministic sample data
/// in `MockData` with a short artificial delay so skeleton loading states are
/// visible and pull-to-refresh feels real.
final class MockVLRDataService: VLRDataService {

    func matches(_ query: MatchQuery) async throws -> [Match] {
        try await delay()
        let pool = MockData.allMatches()
        switch query {
        case .live:
            return pool.filter { $0.status == .live }
        case .upcoming:
            return pool.filter { $0.status == .upcoming }.sorted { $0.time < $1.time }
        case .results:
            return pool.filter { $0.status == .completed }.sorted { $0.time > $1.time }
        }
    }

    func matchDetail(id: String) async throws -> MatchDetail {
        try await delay()
        guard let match = MockData.allMatches().first(where: { $0.id == id }) else {
            throw DataError.notFound
        }
        return MockData.detail(for: match)
    }

    func rankings(region: Region) async throws -> [TeamRanking] {
        try await delay()
        return MockData.rankings(region: region)
    }

    func playerStats(region: Region, timespan: StatsTimespan) async throws -> [PlayerStat] {
        try await delay()
        // Timespan is ignored by the sample data; the real service passes it through.
        return MockData.playerStats(region: region).sorted { $0.rating > $1.rating }
    }

    func events(_ query: EventStatus) async throws -> [VLREvent] {
        try await delay()
        return MockData.events().filter { $0.status == query }
    }

    func eventMatches(eventID: String) async throws -> [Match] {
        try await delay()
        return MockData.eventMatches(eventID: eventID)
    }

    func teamProfile(id: String) async throws -> TeamProfile {
        try await delay()
        guard let profile = MockData.profile(teamID: id) else { throw DataError.notFound }
        return profile
    }

    func news() async throws -> [NewsItem] {
        try await delay()
        return MockData.news()
    }

    func allTeams() async throws -> [Team] {
        try await delay(.milliseconds(250))
        return MockData.teams.sorted { $0.name < $1.name }
    }

    private func delay(_ duration: Duration = .milliseconds(500)) async throws {
        try await Task.sleep(for: duration)
    }
}
