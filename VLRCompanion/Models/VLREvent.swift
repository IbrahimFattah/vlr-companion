import Foundation

enum EventStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case ongoing
    case upcoming
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ongoing: "Ongoing"
        case .upcoming: "Upcoming"
        case .completed: "Completed"
        }
    }
}

struct VLREvent: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    /// "International" or a region name; kept as a string to match API data.
    let region: String
    let status: EventStatus
    let dates: String
    let prizePool: String
}
