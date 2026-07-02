import Foundation

enum Region: String, Codable, CaseIterable, Identifiable, Hashable {
    case americas
    case emea
    case pacific
    case china

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .americas: "Americas"
        case .emea: "EMEA"
        case .pacific: "Pacific"
        case .china: "China"
        }
    }

    /// Region slug used by vlrggapi (`/v2/rankings?region=`, `/v2/stats?region=`).
    var apiValue: String {
        switch self {
        case .americas: "na"
        case .emea: "eu"
        case .pacific: "ap"
        case .china: "cn"
        }
    }
}

struct Player: Codable, Hashable, Identifiable {
    let id: String
    let handle: String
    let realName: String
    /// Flag emoji; swap for a country code once real data is wired in.
    let country: String
    var role: String?
}

struct Team: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let tag: String
    let region: Region
    /// Primary brand color, drives the My Team accent theme.
    let colorHex: String
    /// Real crest image once the API is wired in; nil renders a monogram.
    var logoURL: URL?
}
