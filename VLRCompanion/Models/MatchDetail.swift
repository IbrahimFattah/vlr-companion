import Foundation

enum MapStatus: String, Codable, Hashable {
    case upcoming
    case live
    case completed
}

struct MapResult: Codable, Hashable, Identifiable {
    let name: String
    var score1: Int
    var score2: Int
    var status: MapStatus
    /// Tag of the team that picked the map; nil for the decider.
    var pickedBy: String?
    var agents1: [String]
    var agents2: [String]
    /// Per-player scoreboard lines (real API only; drives the map stats view).
    var players1: [MapPlayerStat] = []
    var players2: [MapPlayerStat] = []

    var id: String { name }
}

/// One scoreboard row, vlr.gg style. Values stay strings — they're display
/// data straight from the source ("+5", "75%", "164").
struct MapPlayerStat: Codable, Hashable, Identifiable {
    let name: String
    let agent: String
    let rating: String
    let acs: String
    let kills: String
    let deaths: String
    let assists: String
    let kdDiff: String
    let kast: String
    let adr: String
    let hsPercent: String
    let firstKills: String
    let firstDeaths: String

    var id: String { name }
}

struct MatchDetail: Codable, Identifiable {
    let match: Match
    var maps: [MapResult]
    /// Human-readable veto lines, e.g. "FNC ban Icebox".
    var vetos: [String]
    var headToHead: String?

    var id: String { match.id }
}
