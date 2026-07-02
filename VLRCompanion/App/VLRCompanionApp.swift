import SwiftUI

/// The single place the app's data source is chosen.
///
/// INTEGRATION POINT: once the self-hosted vlrggapi instance is up, replace
/// the default with `CachingDataService(wrapping: VLRAPIService())`. Nothing
/// else changes — every view reads `@Environment(\.dataService)`.
private struct DataServiceKey: EnvironmentKey {
    static let defaultValue: any VLRDataService = CachingDataService(wrapping: MockVLRDataService())
}

extension EnvironmentValues {
    var dataService: any VLRDataService {
        get { self[DataServiceKey.self] }
        set { self[DataServiceKey.self] = newValue }
    }
}

@main
struct VLRCompanionApp: App {
    @State private var favorites = FavoritesStore()
    @AppStorage("appearance") private var appearance: Appearance = .dark

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(favorites)
                .preferredColorScheme(appearance.colorScheme)
                .tint(Theme.accent)
        }
    }
}
