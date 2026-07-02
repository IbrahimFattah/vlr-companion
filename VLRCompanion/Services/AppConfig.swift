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
}
