import SwiftUI

/// The single place the app's data source is chosen. Controlled by the
/// "Live data" toggle in Settings (UserDefaults "useLiveData", applied on
/// next launch); both sources sit behind the offline cache decorator.
private struct DataServiceKey: EnvironmentKey {
    static let defaultValue: any VLRDataService = {
        if UserDefaults.standard.bool(forKey: "useLiveData") {
            return CachingDataService(wrapping: VLRAPIService())
        }
        return CachingDataService(wrapping: MockVLRDataService())
    }()
}

extension EnvironmentValues {
    var dataService: any VLRDataService {
        get { self[DataServiceKey.self] }
        set { self[DataServiceKey.self] = newValue }
    }
}

@main
struct VLRCompanionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var favorites = FavoritesStore()
    @State private var account = AccountStore()
    @State private var pushRouter = PushRouter.shared
    @State private var notifications = NotificationManager.shared
    @AppStorage("appearance") private var appearance: Appearance = .dark

    init() {
        // Roomy shared cache so AsyncImage (team crests, map art) hits disk
        // instead of the network on every scroll.
        URLCache.shared = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(favorites)
                .environment(account)
                .environment(pushRouter)
                .environment(notifications)
                .preferredColorScheme(appearance.colorScheme)
                .tint(Theme.accent)
        }
    }
}
