import Foundation

/// Offline layer: wraps any `VLRDataService`, writes every successful response
/// to disk, and serves the last good copy when the wrapped service fails
/// (airplane mode, server down). The app is never blank without a connection
/// once it has loaded a screen at least once.
final class CachingDataService: VLRDataService {

    private let base: any VLRDataService
    private let cache = DiskCache()

    init(wrapping base: any VLRDataService) {
        self.base = base
    }

    func matches(_ query: MatchQuery) async throws -> [Match] {
        try await cached("matches-\(query.rawValue)") { try await self.base.matches(query) }
    }

    func matchDetail(id: String) async throws -> MatchDetail {
        try await cached("match-detail-\(id)") { try await self.base.matchDetail(id: id) }
    }

    func rankings(region: Region) async throws -> [TeamRanking] {
        try await cached("rankings-\(region.rawValue)") { try await self.base.rankings(region: region) }
    }

    func playerStats(region: Region, timespan: StatsTimespan) async throws -> [PlayerStat] {
        try await cached("stats-\(region.rawValue)-\(timespan.rawValue)") {
            try await self.base.playerStats(region: region, timespan: timespan)
        }
    }

    func events(_ query: EventStatus) async throws -> [VLREvent] {
        try await cached("events-\(query.rawValue)") { try await self.base.events(query) }
    }

    func eventMatches(eventID: String) async throws -> [Match] {
        try await cached("event-matches-\(eventID)") { try await self.base.eventMatches(eventID: eventID) }
    }

    func teamProfile(id: String) async throws -> TeamProfile {
        try await cached("team-profile-\(id)") { try await self.base.teamProfile(id: id) }
    }

    func news() async throws -> [NewsItem] {
        try await cached("news") { try await self.base.news() }
    }

    func allTeams() async throws -> [Team] {
        try await cached("all-teams") { try await self.base.allTeams() }
    }

    private func cached<T: Codable>(_ key: String, fetch: () async throws -> T) async throws -> T {
        do {
            let fresh = try await fetch()
            cache.save(fresh, key: key)
            return fresh
        } catch {
            if let stale: T = cache.load(key: key) { return stale }
            throw error
        }
    }
}

/// Flat JSON-file cache in Caches/; the system may purge it, which is fine —
/// it only backs the offline fallback.
struct DiskCache {
    private let directory: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = caches.appendingPathComponent("VLRCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent("\(key).json")
    }

    func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: fileURL(key), options: .atomic)
    }

    func load<T: Decodable>(key: String) -> T? {
        guard let data = try? Data(contentsOf: fileURL(key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
