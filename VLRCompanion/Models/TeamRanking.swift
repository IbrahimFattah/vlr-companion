import Foundation

struct TeamRanking: Codable, Hashable, Identifiable {
    let rank: Int
    let team: Team
    let points: Int
    /// Positions moved since last update: positive is up, negative is down.
    let movement: Int
    let record: String

    var id: String { team.id }
}
