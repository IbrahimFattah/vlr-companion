import Foundation

/// Resolution order for the vlrggapi host: user override from Settings →
/// built-in default (local self-hosted instance). Nothing else in the app
/// touches URLs directly.
enum AppConfig {
    static let defaultBaseURLString = "http://127.0.0.1:3001"
    static let baseURLDefaultsKey = "apiBaseURL"

    static var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: baseURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty, let url = URL(string: stored) {
            return url
        }
        return URL(string: defaultBaseURLString)!
    }

    static let assetsBaseURLDefaultsKey = "assetsBaseURL"

    /// Optional CDN/bucket for static assets we host ourselves — faster and
    /// more stable than hotlinking vlr's image CDN. Layout expected:
    ///   {bucket}/logos/{team-slug}.png   (team crests)
    ///   {bucket}/maps/{map-name}.jpg     (map splash art, lowercase)
    /// Unset → team crests use the API-provided URL and map cards render
    /// their built-in gradient art.
    static var assetsBaseURL: URL? {
        let stored = UserDefaults.standard.string(forKey: assetsBaseURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stored, !stored.isEmpty else { return nil }
        return URL(string: stored)
    }
}
