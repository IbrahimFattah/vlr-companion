import Foundation

enum StatsTimespan: String, CaseIterable, Identifiable, Hashable {
    case days30 = "30"
    case days60 = "60"
    case days90 = "90"
    case all = "all"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .days30: "30 days"
        case .days60: "60 days"
        case .days90: "90 days"
        case .all: "All time"
        }
    }
}

struct PlayerStat: Codable, Hashable, Identifiable {
    let id: String
    let handle: String
    let teamTag: String
    let country: String
    let rating: Double
    /// Average combat score.
    let acs: Double
    let kd: Double
    /// Kill/assist/survive/trade percentage.
    let kast: Double
    /// Average damage per round.
    let adr: Double
    let agents: [String]
}
