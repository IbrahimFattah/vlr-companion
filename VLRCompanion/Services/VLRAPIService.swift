import Foundation

/// Live implementation backed by a self-hosted vlrggapi instance
/// (https://github.com/axsddlr/vlrggapi). Response shapes were captured from
/// a running instance (see SELF_HOSTING.md); everything arrives as strings
/// inside a `{"status": "success", "data": {"segments": ...}}` envelope.
///
/// Endpoint map (all `/v2`, rate limit 600 req/min):
///   matches(.live)          GET /v2/match?q=live_score
///   matches(.upcoming)      GET /v2/match?q=upcoming
///   matches(.results)       GET /v2/match?q=results
///   matchDetail(id:)        GET /v2/match/details?match_id={id}
///   rankings(region:)       GET /v2/rankings?region={region.apiValue}
///   playerStats(_:_:)       GET /v2/stats?region=&timespan=
///   events(_:)              GET /v2/events?q=live|upcoming|completed
///   eventMatches(eventID:)  GET /v2/events/matches?event_id={id}
///   teamProfile(id:)        GET /v2/search (slug→numeric id) then
///                           GET /v2/team?id=&q=profile and q=matches
///   news()                  GET /v2/news
///   allTeams()              GET /v2/rankings across all four app regions
///
/// List endpoints carry no numeric team IDs, so teams are identified by a
/// normalized name slug ("name:paper rex"). The slug is stable across
/// endpoints (same normalization everywhere), which keeps favorites and
/// followed-team alerts working; `teamProfile` resolves a slug to the real
/// vlr.gg team id via /v2/search on demand.
final class VLRAPIService: VLRDataService {

    private let session: URLSession
    private let teamIDCache = TeamIDCache()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Transport

    private struct Envelope<T: Decodable>: Decodable {
        let status: String
        let data: T
    }

    private struct SegmentsBox<S: Decodable>: Decodable {
        let segments: S
    }

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: AppConfig.baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw DataError.badResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DataError.badResponse
        }
        // Scraped team/player names occasionally contain raw control
        // characters, which strict JSON decoding rejects — blank them out.
        let sanitized = Data(data.map { $0 < 0x20 ? 0x20 : $0 })
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: sanitized)
        guard envelope.status == "success" else { throw DataError.badResponse }
        return envelope.data
    }

    private func segments<S: Decodable>(_ path: String, _ query: [URLQueryItem] = []) async throws -> S {
        let box: SegmentsBox<S> = try await get(path, query)
        return box.segments
    }

    // MARK: - VLRDataService

    func matches(_ query: MatchQuery) async throws -> [Match] {
        switch query {
        case .live:
            let rows: [LiveMatchDTO] = try await segments("/v2/match", [.init(name: "q", value: "live_score")])
            return rows.compactMap(liveMatch)
        case .upcoming:
            let rows: [UpcomingMatchDTO] = try await segments("/v2/match", [.init(name: "q", value: "upcoming")])
            return rows.compactMap(upcomingMatch).sorted { $0.time < $1.time }
        case .results:
            let rows: [ResultMatchDTO] = try await segments("/v2/match", [.init(name: "q", value: "results")])
            return rows.compactMap(resultMatch).sorted { $0.time > $1.time }
        }
    }

    func matchDetail(id: String) async throws -> MatchDetail {
        let rows: [MatchDetailDTO] = try await segments("/v2/match/details", [.init(name: "match_id", value: id)])
        guard let dto = rows.first, dto.teams.count >= 2 else { throw DataError.notFound }
        return mapDetail(dto, id: id)
    }

    func rankings(region: Region) async throws -> [TeamRanking] {
        let rows: [RankingDTO] = try await segments("/v2/rankings", [.init(name: "region", value: region.apiValue)])
        return rows.compactMap { row in
            guard let rank = Int(row.rank ?? "") else { return nil }
            return TeamRanking(rank: rank,
                               team: team(named: row.team ?? "Unknown", logo: row.logo, region: region),
                               points: nil,
                               movement: 0,
                               record: row.record ?? "",
                               earnings: row.earnings)
        }
    }

    func playerStats(region: Region, timespan: StatsTimespan) async throws -> [PlayerStat] {
        let rows: [PlayerStatDTO] = try await segments("/v2/stats", [
            .init(name: "region", value: region.apiValue),
            .init(name: "timespan", value: timespan.rawValue),
        ])
        return rows.compactMap { row in
            guard let handle = row.player, !handle.isEmpty else { return nil }
            return PlayerStat(id: "\(row.org ?? "")-\(handle)".lowercased(),
                              handle: handle,
                              teamTag: row.org ?? "",
                              country: "",
                              rating: Double(row.rating ?? "") ?? 0,
                              acs: Double(row.averageCombatScore ?? "") ?? 0,
                              kd: Double(row.killDeaths ?? "") ?? 0,
                              kast: percent(row.killAssistsSurvivedTraded),
                              adr: Double(row.averageDamagePerRound ?? "") ?? 0,
                              agents: (row.agents ?? []).map { $0.capitalized })
        }
    }

    func events(_ query: EventStatus) async throws -> [VLREvent] {
        let q = query == .ongoing ? "live" : query.rawValue
        let rows: [EventDTO] = try await segments("/v2/events", [.init(name: "q", value: q)])
        return rows.compactMap { row in
            guard let id = row.eventId, !id.isEmpty else { return nil }
            return VLREvent(id: id,
                            name: row.title ?? "Event",
                            region: expandRegion(row.region),
                            status: query,
                            dates: "",
                            prizePool: "")
        }
    }

    func eventMatches(eventID: String) async throws -> [Match] {
        let rows: [EventMatchDTO] = try await segments("/v2/events/matches", [.init(name: "event_id", value: eventID)])
        return rows.compactMap(eventMatch).sorted { $0.time > $1.time }
    }

    func teamProfile(id: String) async throws -> TeamProfile {
        let numericID = try await resolveTeamID(id)

        async let profileRows: [TeamProfileDTO] = segments("/v2/team", [
            .init(name: "id", value: numericID), .init(name: "q", value: "profile"),
        ])
        async let matchRows: [TeamMatchDTO] = segments("/v2/team", [
            .init(name: "id", value: numericID), .init(name: "q", value: "matches"),
        ])
        async let allUpcoming = matches(.upcoming)

        guard let dto = try await profileRows.first else { throw DataError.notFound }

        let region = regionGuess(dto.countryName ?? "")
        let team = Team(id: id,
                        name: dto.name ?? "Unknown",
                        tag: dto.tag?.isEmpty == false ? dto.tag! : tagGuess(dto.name ?? ""),
                        region: region,
                        colorHex: teamColorHex(dto.name ?? ""),
                        logoURL: normalizedURL(dto.logo))

        let members = dto.roster ?? []
        let roster = members.filter { $0.isStaff != true }.map { player($0, fallbackRegion: region) }
        let staff = members.filter { $0.isStaff == true }.map { player($0, fallbackRegion: region) }

        let results = (try await matchRows).compactMap { teamMatch($0, team: team) }
        let upcoming = ((try? await allUpcoming) ?? []).filter { $0.involves(id) }

        let standing = dto.eventPlacements?.first.map { placement in
            [placement.placement, placement.event]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }

        return TeamProfile(team: team,
                           ranking: nil,
                           record: dto.rating.flatMap { $0.isEmpty ? nil : "\($0) rating" },
                           roster: roster,
                           staff: staff,
                           upcoming: upcoming,
                           results: results,
                           standing: standing)
    }

    func news() async throws -> [NewsItem] {
        let rows: [NewsDTO] = try await segments("/v2/news")
        return rows.compactMap { row in
            guard let title = row.title, !title.isEmpty else { return nil }
            return NewsItem(id: row.urlPath ?? title,
                            title: title,
                            summary: row.description ?? "",
                            author: row.author ?? "vlr.gg",
                            date: Self.newsDateFormatter.date(from: row.date ?? "") ?? .now,
                            url: normalizedURL(row.urlPath))
        }
    }

    func allTeams() async throws -> [Team] {
        try await withThrowingTaskGroup(of: [TeamRanking].self) { group in
            for region in Region.allCases {
                group.addTask { try await self.rankings(region: region) }
            }
            var teams: [String: Team] = [:]
            for try await rankings in group {
                for ranking in rankings {
                    teams[ranking.team.id] = ranking.team
                }
            }
            return teams.values.sorted { $0.name < $1.name }
        }
    }

    // MARK: - Team identity

    /// Normalized, endpoint-stable team identifier: "name:paper rex".
    private func slugID(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "en_US")).lowercased()
        let kept = folded.map { $0.isLetter || $0.isNumber || $0 == " " ? $0 : Character(" ") }
        let collapsed = String(kept).split(separator: " ").joined(separator: " ")
        return "name:" + collapsed
    }

    /// Resolves an app team id (slug or numeric) to a vlr.gg numeric team id
    /// via /v2/search, caching the result for the process lifetime.
    private func resolveTeamID(_ id: String) async throws -> String {
        if id.allSatisfy(\.isNumber) { return id }
        if let cached = await teamIDCache.value(for: id) { return cached }

        let query = id.hasPrefix("name:") ? String(id.dropFirst(5)) : id
        let box: SearchSegmentsDTO = try await segments("/v2/search", [.init(name: "q", value: query)])
        let candidates = box.results?.teams ?? []
        let match = candidates.first { slugID($0.name ?? "") == id } ?? candidates.first
        guard let numeric = match?.id, !numeric.isEmpty else { throw DataError.notFound }
        await teamIDCache.store(numeric, for: id)
        return numeric
    }

    private func team(named name: String, logo: String?, region: Region) -> Team {
        Team(id: slugID(name),
             name: name,
             tag: tagGuess(name),
             region: region,
             colorHex: teamColorHex(name),
             logoURL: normalizedURL(logo))
    }

    private func tagGuess(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(3).compactMap(\.first).map(String.init).joined().uppercased()
        }
        return String(name.prefix(3)).uppercased()
    }

    /// Deterministic brand-ish color per team (real brand colors aren't in
    /// the API). Avoids the reserved live red.
    private static let palette = [
        "5E9EFF", "2CE66C", "FF8A3D", "B48CFF", "00C2D1", "FFD166",
        "FF6FB0", "7ED4B2", "C8CDD6", "F5A623", "6EE7F0", "E2FF3D",
    ]

    private func teamColorHex(_ name: String) -> String {
        let hash = name.utf8.reduce(5381 as UInt64) { ($0 &* 33) &+ UInt64($1) }
        return Self.palette[Int(hash % UInt64(Self.palette.count))]
    }

    private func player(_ dto: RosterMemberDTO, fallbackRegion: Region) -> Player {
        Player(id: dto.id ?? dto.alias ?? UUID().uuidString,
               handle: dto.alias ?? "—",
               realName: dto.realName ?? "",
               country: flagEmoji(dto.country),
               role: dto.isStaff == true ? (dto.role?.isEmpty == false ? dto.role : "Staff") : dto.role)
    }

    // MARK: - Match mapping

    private func liveMatch(_ dto: LiveMatchDTO) -> Match? {
        guard let id = matchID(dto.matchPage), let name1 = dto.team1, let name2 = dto.team2 else { return nil }
        let region = regionGuess(dto.matchEvent ?? "")
        let currentMap = dto.currentMap.flatMap { $0 == "Unknown" || $0.isEmpty ? nil : $0 }
        return Match(id: id,
                     eventName: dto.matchEvent ?? "",
                     stage: dto.matchSeries ?? "",
                     team1: team(named: name1, logo: dto.team1Logo, region: region),
                     team2: team(named: name2, logo: dto.team2Logo, region: region),
                     score1: Int(dto.score1 ?? "") ?? 0,
                     score2: Int(dto.score2 ?? "") ?? 0,
                     status: .live,
                     time: timestampDate(dto.unixTimestamp) ?? .now,
                     format: .unknown,
                     currentMap: currentMap)
    }

    private func upcomingMatch(_ dto: UpcomingMatchDTO) -> Match? {
        guard let id = matchID(dto.matchPage), let name1 = dto.team1, let name2 = dto.team2 else { return nil }
        let region = regionGuess(dto.matchEvent ?? "")
        let time = relativeDate(dto.timeUntilMatch) ?? timestampDate(dto.unixTimestamp) ?? .now
        return Match(id: id,
                     eventName: dto.matchEvent ?? "",
                     stage: dto.matchSeries ?? "",
                     team1: team(named: name1, logo: nil, region: region),
                     team2: team(named: name2, logo: nil, region: region),
                     score1: nil,
                     score2: nil,
                     status: .upcoming,
                     time: time,
                     format: .unknown,
                     currentMap: nil)
    }

    private func resultMatch(_ dto: ResultMatchDTO) -> Match? {
        guard let id = matchID(dto.matchPage), let name1 = dto.team1, let name2 = dto.team2 else { return nil }
        let region = regionGuess(dto.tournamentName ?? "")
        return Match(id: id,
                     eventName: dto.tournamentName ?? "",
                     stage: dto.roundInfo ?? "",
                     team1: team(named: name1, logo: nil, region: region),
                     team2: team(named: name2, logo: nil, region: region),
                     score1: Int(dto.score1 ?? "") ?? 0,
                     score2: Int(dto.score2 ?? "") ?? 0,
                     status: .completed,
                     time: relativeDate(dto.timeCompleted) ?? .now,
                     format: .unknown,
                     currentMap: nil)
    }

    private func eventMatch(_ dto: EventMatchDTO) -> Match? {
        guard let id = dto.matchId, !id.isEmpty,
              let name1 = dto.team1?.name, let name2 = dto.team2?.name,
              !name1.isEmpty, !name2.isEmpty else { return nil }
        let status: MatchStatus
        switch (dto.status ?? "").lowercased() {
        case "completed", "final": status = .completed
        case "live": status = .live
        default: status = .upcoming
        }
        return Match(id: id,
                     eventName: "",
                     stage: dto.eventSeries ?? "",
                     team1: team(named: name1, logo: nil, region: .americas),
                     team2: team(named: name2, logo: nil, region: .americas),
                     score1: status == .upcoming ? nil : Int(dto.team1?.score ?? ""),
                     score2: status == .upcoming ? nil : Int(dto.team2?.score ?? ""),
                     status: status,
                     time: Self.eventMatchDateFormatter.date(from: dto.date ?? "") ?? .now,
                     format: .unknown,
                     currentMap: nil)
    }

    private func teamMatch(_ dto: TeamMatchDTO, team: Team) -> Match? {
        guard let id = dto.matchId, !id.isEmpty,
              let name1 = dto.team1?.name, let name2 = dto.team2?.name else { return nil }
        let scores = (dto.score ?? "").split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        var time = Date.now
        if let date = dto.date {
            let combined = "\(date) \(dto.time ?? "12:00 pm")"
            time = Self.teamMatchDateFormatter.date(from: combined)
                ?? Self.teamMatchDateOnlyFormatter.date(from: date)
                ?? .now
        }
        return Match(id: id,
                     eventName: dto.event ?? "",
                     stage: "",
                     team1: self.team(named: name1, logo: dto.team1?.logo, region: team.region),
                     team2: self.team(named: name2, logo: dto.team2?.logo, region: team.region),
                     score1: scores.count == 2 ? scores[0] : nil,
                     score2: scores.count == 2 ? scores[1] : nil,
                     status: .completed,
                     time: time,
                     format: .unknown,
                     currentMap: nil)
    }

    private func mapDetail(_ dto: MatchDetailDTO, id: String) -> MatchDetail {
        let region = regionGuess(dto.event?.name ?? "")
        let t1DTO = dto.teams[0]
        let t2DTO = dto.teams[1]

        let status: MatchStatus
        switch (dto.status ?? "").lowercased() {
        case "final", "completed": status = .completed
        case "live": status = .live
        default: status = .upcoming
        }

        // event.name often has the series glued on the end — trim it.
        var eventName = dto.event?.name ?? ""
        if let series = dto.event?.series, !series.isEmpty, eventName.hasSuffix(series) {
            eventName = String(eventName.dropLast(series.count)).trimmingCharacters(in: .whitespaces)
        }

        let mapCount = dto.maps?.count ?? 0
        let format: MatchFormat = mapCount >= 4 ? .bo5 : mapCount >= 2 ? .bo3 : .unknown

        func makeTeam(_ teamDTO: DetailTeamDTO) -> Team {
            let base = team(named: teamDTO.name ?? "Unknown", logo: teamDTO.logo, region: region)
            guard let tag = teamDTO.tag, !tag.isEmpty else { return base }
            return Team(id: base.id, name: base.name, tag: tag, region: base.region,
                        colorHex: base.colorHex, logoURL: base.logoURL)
        }

        let team1 = makeTeam(t1DTO)
        let team2 = makeTeam(t2DTO)

        let match = Match(id: id,
                          eventName: eventName,
                          stage: dto.event?.series ?? "",
                          team1: team1,
                          team2: team2,
                          score1: t1DTO.score?.value,
                          score2: t2DTO.score?.value,
                          status: status,
                          time: .now,
                          format: format,
                          currentMap: status == .live ? dto.maps?.last?.mapName : nil,
                          streamURL: normalizedURL(dto.streams?.elements.first?.url),
                          vodURL: normalizedURL(dto.vods?.elements.first?.url))

        let tags = (team1.tag, team2.tag)

        let vetos = (dto.mapVetos ?? "")
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // The scraper's per-map picked_by is unreliable ("PICK"); rebuild the
        // picks from the veto lines: "GGA pick Ascent" / "Haven remains".
        var pickerByMapName: [String: String] = [:]
        for line in vetos {
            let parts = line.split(separator: " ").map(String.init)
            if parts.count >= 3, parts[1].lowercased() == "pick" {
                pickerByMapName[parts[2...].joined(separator: " ").lowercased()] = parts[0]
            } else if parts.count >= 2, parts.last?.lowercased() == "remains" {
                pickerByMapName[parts.dropLast().joined(separator: " ").lowercased()] = "DECIDER"
            }
        }

        let maps: [MapResult] = (dto.maps ?? []).enumerated().map { index, mapDTO in
            let isLast = index == mapCount - 1
            let mapStatus: MapStatus = status == .completed ? .completed
                : status == .live ? (isLast ? .live : .completed)
                : .upcoming
            let rawPick = mapDTO.pickedBy?.trimmingCharacters(in: .whitespaces) ?? ""
            let pickedBy: String?
            if !rawPick.isEmpty, rawPick.uppercased() != "PICK", rawPick.uppercased() != "DECIDER" {
                pickedBy = rawPick
            } else {
                pickedBy = pickerByMapName[(mapDTO.mapName ?? "").lowercased()]
            }
            return MapResult(name: mapDTO.mapName ?? "Map \(index + 1)",
                             score1: mapDTO.score?.team1?.value ?? 0,
                             score2: mapDTO.score?.team2?.value ?? 0,
                             status: mapStatus,
                             pickedBy: pickedBy,
                             agents1: (mapDTO.players?.team1 ?? []).compactMap { $0.agent?.capitalized },
                             agents2: (mapDTO.players?.team2 ?? []).compactMap { $0.agent?.capitalized },
                             players1: (mapDTO.players?.team1 ?? []).map(mapPlayer),
                             players2: (mapDTO.players?.team2 ?? []).map(mapPlayer))
        }

        var headToHead: String?
        if let h2h = dto.headToHead?.elements, !h2h.isEmpty {
            let latest = h2h[0]
            let score = (latest.score ?? "").replacingOccurrences(of: " ", with: "–")
            headToHead = "\(h2h.count) recent meeting\(h2h.count == 1 ? "" : "s") between \(tags.0) and \(tags.1) — last: \(latest.event ?? "unknown event") (\(score))"
        }

        return MatchDetail(match: match, maps: maps, vetos: vetos, headToHead: headToHead)
    }

    private func mapPlayer(_ dto: MapPlayerDTO) -> MapPlayerStat {
        MapPlayerStat(name: dto.name ?? "—",
                      agent: dto.agent?.capitalized ?? "",
                      rating: dto.rating ?? "",
                      acs: dto.acs ?? "",
                      kills: dto.kills ?? "",
                      deaths: dto.deaths ?? "",
                      assists: dto.assists ?? "",
                      kdDiff: dto.kdDiff ?? "",
                      kast: dto.kast ?? "",
                      adr: dto.adr ?? "",
                      hsPercent: dto.hsPct ?? "",
                      firstKills: dto.fk ?? "",
                      firstDeaths: dto.fd ?? "")
    }

    // MARK: - Parsing helpers

    private func matchID(_ page: String?) -> String? {
        guard var page else { return nil }
        if page.hasPrefix("/") { page.removeFirst() }
        let digits = page.prefix { $0.isNumber }
        return digits.isEmpty ? nil : String(digits)
    }

    private func percent(_ value: String?) -> Double {
        Double((value ?? "").replacingOccurrences(of: "%", with: "")) ?? 0
    }

    private func normalizedURL(_ raw: String?) -> URL? {
        guard var raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("//") { raw = "https:" + raw }
        if raw.hasPrefix("/") { raw = "https://www.vlr.gg" + raw }
        return URL(string: raw)
    }

    private func flagEmoji(_ code: String?) -> String {
        guard let code, code.count == 2 else { return "" }
        return String(code.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value).map(Character.init)
        })
    }

    /// Best-effort bucket into the app's four regions from event/country text.
    private func regionGuess(_ text: String) -> Region {
        let lower = text.lowercased()
        func hasAny(_ needles: [String]) -> Bool {
            needles.contains { lower.contains($0) }
        }
        if hasAny(["china"]) { return .china }
        if hasAny(["emea", "europe", "türkiye", "turkey", "mena", "france", "spain", "germany",
                   "united kingdom", "poland", "cis", "ukraine"]) { return .emea }
        if hasAny(["pacific", "korea", "japan", "southeast asia", "south asia", "oceania",
                   "india", "indonesia", "singapore", "thailand", "philippines", "vietnam",
                   "malaysia", "apac"]) { return .pacific }
        return .americas
    }

    private func expandRegion(_ abbreviation: String?) -> String {
        switch (abbreviation ?? "").uppercased() {
        case "NA": "North America"
        case "EU": "Europe"
        case "PAC", "AP": "Pacific"
        case "CN": "China"
        case "SA", "LA", "LATAM": "Latin America"
        case "BR": "Brazil"
        case "JP": "Japan"
        case "KR": "Korea"
        case "OCE": "Oceania"
        case "GC": "Game Changers"
        case "INTL", "": "International"
        default: abbreviation ?? "International"
        }
    }

    /// Parses vlr's relative times: "39m from now", "2h 21m ago", "1d 2h from now".
    private func relativeDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let lower = raw.lowercased()
        var seconds: Double = 0
        var number = ""
        var index = lower.startIndex
        while index < lower.endIndex {
            let char = lower[index]
            if char.isNumber {
                number.append(char)
            } else if !number.isEmpty {
                let unitStart = index
                var unit = ""
                var cursor = unitStart
                while cursor < lower.endIndex, lower[cursor].isLetter {
                    unit.append(lower[cursor])
                    cursor = lower.index(after: cursor)
                }
                let value = Double(number) ?? 0
                switch true {
                case unit.hasPrefix("mo"): seconds += value * 2_592_000
                case unit.hasPrefix("w"): seconds += value * 604_800
                case unit.hasPrefix("d"): seconds += value * 86_400
                case unit.hasPrefix("h"): seconds += value * 3_600
                case unit.hasPrefix("m"): seconds += value * 60
                case unit.hasPrefix("s"): seconds += value
                default: break
                }
                number = ""
                index = cursor
                continue
            }
            index = lower.index(after: index)
        }
        guard seconds > 0 else { return nil }
        return lower.contains("ago") ? Date.now.addingTimeInterval(-seconds)
                                     : Date.now.addingTimeInterval(seconds)
    }

    private func timestampDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return Self.timestampFormatter.date(from: raw)
    }

    private static let timestampFormatter: DateFormatter = makeFormatter("yyyy-MM-dd HH:mm:ss", utc: true)
    private static let newsDateFormatter: DateFormatter = makeFormatter("MMMM d, yyyy")
    private static let eventMatchDateFormatter: DateFormatter = makeFormatter("EEE, MMM d, yyyy")
    private static let teamMatchDateFormatter: DateFormatter = makeFormatter("yyyy/MM/dd h:mm a")
    private static let teamMatchDateOnlyFormatter: DateFormatter = makeFormatter("yyyy/MM/dd")

    private static func makeFormatter(_ format: String, utc: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        if utc { formatter.timeZone = TimeZone(identifier: "UTC") }
        return formatter
    }

    // MARK: - DTOs (snake_case handled via CodingKeys)

    private struct LiveMatchDTO: Decodable {
        let team1, team2, score1, score2: String?
        let team1Logo, team2Logo, currentMap, matchEvent, matchSeries, unixTimestamp, matchPage: String?
        enum CodingKeys: String, CodingKey {
            case team1, team2, score1, score2
            case team1Logo = "team1_logo", team2Logo = "team2_logo"
            case currentMap = "current_map", matchEvent = "match_event"
            case matchSeries = "match_series", unixTimestamp = "unix_timestamp", matchPage = "match_page"
        }
    }

    private struct UpcomingMatchDTO: Decodable {
        let team1, team2, timeUntilMatch, matchSeries, matchEvent, unixTimestamp, matchPage: String?
        enum CodingKeys: String, CodingKey {
            case team1, team2
            case timeUntilMatch = "time_until_match", matchSeries = "match_series"
            case matchEvent = "match_event", unixTimestamp = "unix_timestamp", matchPage = "match_page"
        }
    }

    private struct ResultMatchDTO: Decodable {
        let team1, team2, score1, score2, timeCompleted, roundInfo, tournamentName, matchPage: String?
        enum CodingKeys: String, CodingKey {
            case team1, team2, score1, score2
            case timeCompleted = "time_completed", roundInfo = "round_info"
            case tournamentName = "tournament_name", matchPage = "match_page"
        }
    }

    private struct RankingDTO: Decodable {
        let rank, team, country, record, earnings, logo: String?
    }

    private struct PlayerStatDTO: Decodable {
        let player, org, rating, averageCombatScore, killDeaths: String?
        let killAssistsSurvivedTraded, averageDamagePerRound, headshotPercentage: String?
        let agents: [String]?
        enum CodingKeys: String, CodingKey {
            case player, org, rating, agents
            case averageCombatScore = "average_combat_score"
            case killDeaths = "kill_deaths"
            case killAssistsSurvivedTraded = "kill_assists_survived_traded"
            case averageDamagePerRound = "average_damage_per_round"
            case headshotPercentage = "headshot_percentage"
        }
    }

    private struct EventDTO: Decodable {
        let title, eventId, status, region, thumb, urlPath: String?
        enum CodingKeys: String, CodingKey {
            case title, status, region, thumb
            case eventId = "event_id", urlPath = "url_path"
        }
    }

    private struct EventMatchDTO: Decodable {
        struct Side: Decodable {
            let name, score: String?
        }
        let matchId, date, status, eventSeries: String?
        let team1, team2: Side?
        enum CodingKeys: String, CodingKey {
            case date, status, team1, team2
            case matchId = "match_id", eventSeries = "event_series"
        }
    }

    private struct NewsDTO: Decodable {
        let title, description, date, author, urlPath: String?
        enum CodingKeys: String, CodingKey {
            case title, description, date, author
            case urlPath = "url_path"
        }
    }

    private struct SearchSegmentsDTO: Decodable {
        struct Results: Decodable {
            let teams: [SearchTeamDTO]?
        }
        let results: Results?
    }

    private struct SearchTeamDTO: Decodable {
        let id, name, img: String?
    }

    private struct TeamProfileDTO: Decodable {
        let id, name, tag, logo, country, countryName, rating: String?
        let roster: [RosterMemberDTO]?
        let eventPlacements: [PlacementDTO]?
        enum CodingKeys: String, CodingKey {
            case id, name, tag, logo, country, rating, roster
            case countryName = "country_name"
            case eventPlacements = "event_placements"
        }
    }

    private struct RosterMemberDTO: Decodable {
        let id, alias, realName, country, role: String?
        let isStaff: Bool?
        enum CodingKeys: String, CodingKey {
            case id, alias, country, role
            case realName = "real_name", isStaff = "is_staff"
        }
    }

    private struct PlacementDTO: Decodable {
        let event, placement: String?
    }

    private struct TeamMatchDTO: Decodable {
        struct Side: Decodable {
            let name, tag, logo: String?
        }
        let matchId, event, date, time, score: String?
        let team1, team2: Side?
        enum CodingKeys: String, CodingKey {
            case event, date, time, score, team1, team2
            case matchId = "match_id"
        }
    }

    private struct MatchDetailDTO: Decodable {
        struct EventInfo: Decodable {
            let name, series, logo: String?
        }
        let matchId, date, mapVetos, status: String?
        let event: EventInfo?
        let teams: [DetailTeamDTO]
        let streams: LossyArray<NamedLinkDTO>?
        let vods: LossyArray<NamedLinkDTO>?
        let maps: [MapDTO]?
        let headToHead: LossyArray<H2HDTO>?
        enum CodingKeys: String, CodingKey {
            case date, status, event, teams, streams, vods, maps
            case matchId = "match_id", mapVetos = "map_vetos", headToHead = "head_to_head"
        }
    }

    private struct DetailTeamDTO: Decodable {
        let id, name, tag, logo: String?
        let score: FlexInt?
    }

    private struct NamedLinkDTO: Decodable {
        let name, url: String?
    }

    private struct H2HDTO: Decodable {
        let event, date, score, url: String?
    }

    private struct MapDTO: Decodable {
        struct Score: Decodable {
            let team1, team2: FlexInt?
        }
        struct Players: Decodable {
            let team1, team2: [MapPlayerDTO]?
        }
        let mapName, pickedBy, duration: String?
        let score: Score?
        let players: Players?
        enum CodingKeys: String, CodingKey {
            case score, players, duration
            case mapName = "map_name", pickedBy = "picked_by"
        }
    }

    private struct MapPlayerDTO: Decodable {
        let name, agent, rating, acs, kills, deaths, assists: String?
        let kdDiff, kast, adr, hsPct, fk, fd, fkDiff: String?
        enum CodingKeys: String, CodingKey {
            case name, agent, rating, acs, kills, deaths, assists, kast, adr, fk, fd
            case kdDiff = "kd_diff", hsPct = "hs_pct", fkDiff = "fk_diff"
        }
    }
}

// MARK: - Decoding utilities

/// Accepts JSON numbers or numeric strings — the scraper mixes both.
struct FlexInt: Decodable {
    let value: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self) {
            value = Int(string.trimmingCharacters(in: .whitespaces))
        } else {
            value = nil
        }
    }
}

/// Array that skips elements failing to decode instead of failing the whole
/// payload — scraper output is only mostly regular.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var collected: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                collected.append(element)
            } else {
                _ = try? container.decode(AnyJSON.self)
            }
        }
        elements = collected
    }

    private enum AnyJSON: Decodable {
        case value
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .value; return }
            if (try? container.decode(Bool.self)) != nil { self = .value; return }
            if (try? container.decode(Double.self)) != nil { self = .value; return }
            if (try? container.decode(String.self)) != nil { self = .value; return }
            if (try? container.decode([String: Self].self)) != nil { self = .value; return }
            if (try? container.decode([Self].self)) != nil { self = .value; return }
            self = .value
        }
    }
}

/// Process-lifetime slug → numeric vlr.gg team id cache.
private actor TeamIDCache {
    private var storage: [String: String] = [:]

    func value(for key: String) -> String? {
        storage[key]
    }

    func store(_ value: String, for key: String) {
        storage[key] = value
    }
}
