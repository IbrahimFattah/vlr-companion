import Foundation

/// Real implementation backed by a self-hosted vlrggapi instance
/// (https://github.com/axsddlr/vlrggapi). NOT registered yet — the app runs on
/// `MockVLRDataService` until UI testing completes. To go live, swap the
/// service in `DataServiceKey` (VLRCompanionApp.swift) for:
///
///     CachingDataService(wrapping: VLRAPIService())
///
/// Endpoint map (all `/v2`, envelope `{"status": "success", "data": ...}`,
/// rate limit 600 req/min):
///
///   matches(.live)          GET /v2/match?q=live_score
///   matches(.upcoming)      GET /v2/match?q=upcoming
///   matches(.results)       GET /v2/match?q=results
///   matchDetail(id:)        GET /v2/match/details?match_id={id}
///   rankings(region:)       GET /v2/rankings?region={region.apiValue}
///   playerStats(_:_:)       GET /v2/stats?region={region.apiValue}&timespan={timespan.rawValue}
///   events(_:)              GET /v2/events?q={upcoming|completed|live}
///   eventMatches(eventID:)  GET /v2/events/matches?event_id={id}
///   teamProfile(id:)        GET /v2/team?id={id}&q=profile (+ q=matches for history)
///   news()                  GET /v2/news
///   allTeams()              no direct endpoint — seed from /v2/rankings per
///                           region, or /v2/search?q= for the onboarding picker
///
/// The base URL is configurable (Settings → Data Source) via `AppConfig`;
/// nothing here or in the UI hardcodes a host. Note: when pointing a device
/// or simulator at plain-HTTP hosts, add an ATS exception
/// (NSAppTransportSecurity → NSAllowsLocalNetworking) to the target's Info
/// settings — see README.
final class VLRAPIService: VLRDataService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Envelope

    private struct Envelope<T: Decodable>: Decodable {
        let status: String
        let data: T
    }

    /// Shared GET + envelope unwrap. Response mapping into app models is the
    /// remaining integration work in each method below.
    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: AppConfig.baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw DataError.badResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DataError.badResponse
        }
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        guard envelope.status == "success" else { throw DataError.badResponse }
        return envelope.data
    }

    // MARK: - VLRDataService (integration TODOs)

    func matches(_ query: MatchQuery) async throws -> [Match] {
        // TODO: GET /v2/match?q=... then map the segments payload to [Match].
        throw DataError.notImplemented("/v2/match?q=\(apiQuery(for: query))")
    }

    func matchDetail(id: String) async throws -> MatchDetail {
        // TODO: GET /v2/match/details?match_id=... → maps, agents, vetos, h2h.
        throw DataError.notImplemented("/v2/match/details?match_id=\(id)")
    }

    func rankings(region: Region) async throws -> [TeamRanking] {
        // TODO: GET /v2/rankings?region=... → [TeamRanking].
        throw DataError.notImplemented("/v2/rankings?region=\(region.apiValue)")
    }

    func playerStats(region: Region, timespan: StatsTimespan) async throws -> [PlayerStat] {
        // TODO: GET /v2/stats?region=...&timespan=... → [PlayerStat].
        throw DataError.notImplemented("/v2/stats?region=\(region.apiValue)&timespan=\(timespan.rawValue)")
    }

    func events(_ query: EventStatus) async throws -> [VLREvent] {
        // TODO: GET /v2/events?q=... (API uses "live" where the app says "ongoing").
        let q = query == .ongoing ? "live" : query.rawValue
        throw DataError.notImplemented("/v2/events?q=\(q)")
    }

    func eventMatches(eventID: String) async throws -> [Match] {
        // TODO: GET /v2/events/matches?event_id=...
        throw DataError.notImplemented("/v2/events/matches?event_id=\(eventID)")
    }

    func teamProfile(id: String) async throws -> TeamProfile {
        // TODO: GET /v2/team?id=...&q=profile plus q=matches for match history.
        throw DataError.notImplemented("/v2/team?id=\(id)")
    }

    func news() async throws -> [NewsItem] {
        // TODO: GET /v2/news → [NewsItem].
        throw DataError.notImplemented("/v2/news")
    }

    func allTeams() async throws -> [Team] {
        // TODO: aggregate /v2/rankings across regions (team id, name, region),
        // or back the onboarding picker with /v2/search?q=.
        throw DataError.notImplemented("teams via /v2/rankings or /v2/search")
    }

    private func apiQuery(for query: MatchQuery) -> String {
        switch query {
        case .live: "live_score"
        case .upcoming: "upcoming"
        case .results: "results"
        }
    }
}
