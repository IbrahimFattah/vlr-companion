import Foundation

struct TeamProfile: Codable, Identifiable {
    let team: Team
    var ranking: Int?
    var record: String?
    var roster: [Player]
    var staff: [Player]
    var upcoming: [Match]
    var results: [Match]
    /// Current tournament standing, e.g. "2nd · Group A".
    var standing: String?

    var id: String { team.id }
}
