import Foundation

struct TeamRanking: Codable, Hashable, Identifiable {
    let rank: Int
    let team: Team
    /// VLR ranking points; nil when the data source doesn't expose them.
    let points: Int?
    /// Positions moved since last update: positive is up, negative is down.
    let movement: Int
    let record: String
    /// Career earnings string (e.g. "$378,266"); shown when points are absent.
    var earnings: String? = nil

    var id: String { team.id }
}
