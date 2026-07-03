import SwiftUI

/// The Community tab: your profile up top, then the general discussion board.
/// Match- and event-specific threads still live in their detail screens; this
/// is the home for your identity and the app-wide conversation.
struct CommunityView: View {
    @Environment(AccountStore.self) private var account
    @State private var showSignIn = false
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeader
                    DiscussionView(scope: "general", ref: "main")
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Community")
            .sheet(isPresented: $showSignIn) { SignInView() }
            .sheet(isPresented: $showEdit) {
                if let profile = account.account { ProfileEditView(account: profile) }
            }
        }
    }

    @ViewBuilder
    private var profileHeader: some View {
        if let profile = account.account {
            HStack(spacing: 14) {
                AccountAvatar(emoji: profile.avatarEmoji, colorHex: profile.avatarColor, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.username).font(.title3.weight(.bold))
                    Text("Community member").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Edit") { showEdit = true }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.elevated, in: Capsule())
            }
            .padding(16)
            .cardBackground()
        } else if account.isAvailable {
            VStack(alignment: .leading, spacing: 12) {
                Text("Join the conversation")
                    .font(.headline)
                Text("Sign in to post in match threads and the community board, and to pick a username and avatar.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button {
                    showSignIn = true
                } label: {
                    Label("Sign in", systemImage: "person.crop.circle")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(Theme.background)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardBackground()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Community is offline")
                    .font(.headline)
                Text("Add an API server URL in Settings → Data source to enable profiles and discussion.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardBackground()
        }
    }
}
