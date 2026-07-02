import Foundation

enum MatchStatus: String, Codable, Hashable {
    case upcoming
    case live
    case completed
}

enum MatchFormat: String, Codable, Hashable {
    case bo1
    case bo3
    case bo5
    /// Real match lists don't expose the format; UI hides it when unknown.
    case unknown

    var display: String {
        switch self {
        case .bo1: "Bo1"
        case .bo3: "Bo3"
        case .bo5: "Bo5"
        case .unknown: ""
        }
    }

    var mapsToWin: Int {
        switch self {
        case .bo1: 1
        case .bo3, .unknown: 2
        case .bo5: 3
        }
    }
}

struct Match: Codable, Hashable, Identifiable {
    let id: String
    let eventName: String
    let stage: String
    let team1: Team
    let team2: Team
    var score1: Int?
    var score2: Int?
    var status: MatchStatus
    var time: Date
    var format: MatchFormat
    /// Map currently being played, live matches only.
    var currentMap: String?
    var streamURL: URL?
    var vodURL: URL?
}

extension Match {
    func involves(_ teamID: String?) -> Bool {
        guard let teamID else { return false }
        return team1.id == teamID || team2.id == teamID
    }

    /// nil when the match isn't finished or the team didn't play in it.
    func didWin(_ teamID: String) -> Bool? {
        guard status == .completed, let score1, let score2 else { return nil }
        if team1.id == teamID { return score1 > score2 }
        if team2.id == teamID { return score2 > score1 }
        return nil
    }

    func opponent(of teamID: String) -> Team? {
        if team1.id == teamID { return team2 }
        if team2.id == teamID { return team1 }
        return nil
    }

    var team1Won: Bool { (score1 ?? 0) > (score2 ?? 0) }
    var team2Won: Bool { (score2 ?? 0) > (score1 ?? 0) }
}
