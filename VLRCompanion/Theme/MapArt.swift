import SwiftUI

/// Visual identity per Valorant map: a signature duotone used as the map
/// card banner, plus the bucket URL for real splash art once the asset
/// bucket (AppConfig.assetsBaseURL) is populated.
enum MapArt {

    /// Signature gradient pair, keyed by map name.
    static func colors(for map: String) -> (Color, Color) {
        switch map.lowercased() {
        case "ascent": (Color(hex: "3BAF9C"), Color(hex: "1D5C55"))
        case "bind": (Color(hex: "D98E4A"), Color(hex: "7A4423"))
        case "haven": (Color(hex: "B0A04A"), Color(hex: "4E5B33"))
        case "split": (Color(hex: "7FD4C1"), Color(hex: "35505F"))
        case "lotus": (Color(hex: "C77FD4"), Color(hex: "5B3570"))
        case "sunset": (Color(hex: "E86A4A"), Color(hex: "7A2E3B"))
        case "icebox": (Color(hex: "6FC7E8"), Color(hex: "2E4E7A"))
        case "breeze": (Color(hex: "58D6B9"), Color(hex: "2A6E77"))
        case "abyss": (Color(hex: "7B6FE8"), Color(hex: "2E2A66"))
        case "fracture": (Color(hex: "8FD45E"), Color(hex: "3B5C2A"))
        case "pearl": (Color(hex: "5EA0D4"), Color(hex: "2A3B5C"))
        case "corrode": (Color(hex: "D4A15E"), Color(hex: "5C452A"))
        default: (Color(hex: "8A93A6"), Color(hex: "3A4150"))
        }
    }

    /// Bucket-hosted splash art. Nil until an assets bucket is configured;
    /// the gradient banner is the built-in look, not a fallback state.
    static func imageURL(for map: String) -> URL? {
        guard let base = AppConfig.assetsBaseURL else { return nil }
        let slug = map.lowercased().replacingOccurrences(of: " ", with: "-")
        return base.appendingPathComponent("maps/\(slug).jpg")
    }
}
