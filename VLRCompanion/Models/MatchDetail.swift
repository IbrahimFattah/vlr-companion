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
