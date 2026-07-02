import Foundation

enum MatchQuery: String, CaseIterable, Identifiable, Hashable {
    case live
    case upcoming
    case results

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .live: "Live"
        case .upcoming: "Upcoming"
        case .results: "Results"
        }
    }
}

enum DataError: LocalizedError {
    case notFound
    case notImplemented(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notFound: "That item is no longer available."
        case .notImplemented(let hint): "Not wired up yet: \(hint)"
        case .badResponse: "The server returned an unexpected response."
        }
    }
}

/// Single seam between UI and data. Views only ever see this protocol, so the
/// backing source (mock data today, self-hosted vlrggapi later) can be swapped
/// in one place — see `DataServiceKey` in VLRCompanionApp.swift.
protocol VLRDataService: Sendable {
    func matches(_ query: MatchQuery) async throws -> [Match]
    func matchDetail(id: String) async throws -> MatchDetail
    func rankings(region: Region) async throws -> [TeamRanking]
    func playerStats(region: Region, timespan: StatsTimespan) async throws -> [PlayerStat]
    func events(_ query: EventStatus) async throws -> [VLREvent]
    func eventMatches(eventID: String) async throws -> [Match]
    func teamProfile(id: String) async throws -> TeamProfile
    func news() async throws -> [NewsItem]
    func allTeams() async throws -> [Team]
}
