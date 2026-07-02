import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FavoritesStore.self) private var favorites

    @AppStorage("appearance") private var appearance: Appearance = .dark
    @AppStorage("matchAlerts") private var matchAlerts = true
    @AppStorage(AppConfig.baseURLDefaultsKey) private var baseURL = ""
    @AppStorage(AppConfig.assetsBaseURLDefaultsKey) private var assetsURL = ""
    @AppStorage("useLiveData") private var useLiveData = false
    @State private var showTeamPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { appearance in
                            Text(appearance.label).tag(appearance)
                        }
                    }
                }

                Section("My team") {
                    if let team = favorites.favoriteTeam {
                        HStack(spacing: 12) {
                            TeamLogoView(team: team, size: 30)
                            Text(team.name)
                            Spacer()
                            Text(team.region.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Change favorite team") { showTeamPicker = true }
                    Button("Redo onboarding", role: .destructive) {
                        favorites.reset()
                        dismiss()
                    }
                }

                Section {
                    Toggle("Match alerts", isOn: $matchAlerts)
                        .tint(Theme.win)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("A haptic and notification fire when a followed team's match goes live while the app is open. Background alerts arrive with the server integration.")
                }

                Section {
                    Toggle("Live data (vlrggapi)", isOn: $useLiveData)
                        .tint(Theme.win)
                    LabeledContent("Source", value: useLiveData ? "vlrggapi" : "Sample data")
                    TextField("API base URL", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Assets bucket URL (optional)", text: $assetsURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Data source")
                } footer: {
                    Text("Live data needs a running vlrggapi instance and applies on next launch. Leave the API URL empty for the default: \(AppConfig.defaultBaseURLString). The assets bucket serves self-hosted team crests (logos/) and map art (maps/).")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Link("VLR.gg", destination: URL(string: "https://www.vlr.gg")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showTeamPicker) { TeamPickerSheet() }
        }
    }
}
