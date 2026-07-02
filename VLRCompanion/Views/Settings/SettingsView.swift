import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FavoritesStore.self) private var favorites
    @Environment(NotificationManager.self) private var notifications
    @Environment(AccountStore.self) private var account

    @AppStorage("appearance") private var appearance: Appearance = .dark
    @AppStorage(AppConfig.accountsBaseURLDefaultsKey) private var accountsURL = ""
    @State private var showSignIn = false
    @State private var showProfileEdit = false
    @State private var showDeleteConfirm = false
    @AppStorage(NotificationManager.Key.live) private var alertLive = true
    @AppStorage(NotificationManager.Key.startingSoon) private var alertStartingSoon = true
    @AppStorage(NotificationManager.Key.finished) private var alertFinished = false
    @AppStorage(NotificationManager.Key.majorFinals) private var alertMajorFinals = false
    @AppStorage(AppConfig.baseURLDefaultsKey) private var baseURL = ""
    @AppStorage(AppConfig.assetsBaseURLDefaultsKey) private var assetsURL = ""
    @AppStorage(AppConfig.pushBackendURLDefaultsKey) private var pushURL = ""
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

                accountSection

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
                    switch notifications.authorizationStatus {
                    case .authorized, .provisional, .ephemeral:
                        Label("Notifications enabled", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.win)
                    case .denied:
                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            Label("Enable in iOS Settings", systemImage: "exclamationmark.triangle.fill")
                        }
                    default:
                        Button {
                            Task { await notifications.enableNotifications() }
                        } label: {
                            Label("Turn on notifications", systemImage: "bell.badge")
                        }
                    }

                    Toggle("Match starting soon", isOn: $alertStartingSoon)
                        .tint(Theme.win)
                        .onChange(of: alertStartingSoon) { notifications.preferencesChanged() }
                    Toggle("Match goes live", isOn: $alertLive)
                        .tint(Theme.win)
                        .onChange(of: alertLive) { notifications.preferencesChanged() }
                    Toggle("Final score", isOn: $alertFinished)
                        .tint(Theme.win)
                        .onChange(of: alertFinished) { notifications.preferencesChanged() }
                    Toggle("Major event finals", isOn: $alertMajorFinals)
                        .tint(Theme.win)
                        .onChange(of: alertMajorFinals) { notifications.preferencesChanged() }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("“Match goes live” also fires a haptic in-app. The other alerts need the push server configured below and are delivered by APNs while the app is closed. “Major event finals” covers playoff finals of majors even for teams you don't follow.")
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
                    TextField("Push server URL (optional)", text: $pushURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: pushURL) { notifications.preferencesChanged() }
                    TextField("API server URL (accounts, optional)", text: $accountsURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Data source")
                } footer: {
                    Text("Live data needs a running vlrggapi instance and applies on next launch. Leave the API URL empty for the default: \(AppConfig.defaultBaseURLString). The assets bucket serves self-hosted team crests (logos/) and map art (maps/). The push server (push-server/) sends background match alerts; the API server (api-server/) powers accounts and discussion.")
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
            .sheet(isPresented: $showSignIn) { SignInView() }
            .sheet(isPresented: $showProfileEdit) {
                if let account = account.account { ProfileEditView(account: account) }
            }
            .confirmationDialog("Delete account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    Task { try? await account.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your profile, posts, and synced favorites. This can't be undone.")
            }
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if !account.isAvailable {
                Text("Set an API server URL below to enable accounts and discussion.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let profile = account.account {
                HStack(spacing: 12) {
                    AccountAvatar(emoji: profile.avatarEmoji, colorHex: profile.avatarColor, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.username).fontWeight(.semibold)
                        Text("Signed in").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("Edit profile") { showProfileEdit = true }
                Button("Sign out") { account.signOut() }
                Button("Delete account", role: .destructive) { showDeleteConfirm = true }
            } else {
                Button {
                    showSignIn = true
                } label: {
                    Label("Sign in", systemImage: "person.crop.circle")
                }
            }
        }
    }
}
