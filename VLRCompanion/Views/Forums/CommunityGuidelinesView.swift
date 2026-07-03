import SwiftUI

/// Community rules, moderator contact, and the agree gate shown before a user's
/// first post. App Store review (guideline 1.2) requires that apps with
/// user-generated content have: an agreement to terms with no tolerance for
/// objectionable content, a way to report and block, and a way to reach a
/// moderator. Reporting and blocking live in the post menu; this screen carries
/// the agreement and the contact.
struct CommunityGuidelinesView: View {
    /// Called when the user accepts; nil in read-only mode (just closes).
    var onAgree: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// Moderators handle reports here. Swap for your own address when you host.
    static let contactEmail = "moderation@vlrcompanion.app"

    private var contactURL: URL? {
        URL(string: "mailto:\(Self.contactEmail)?subject=VLR%20Companion%20moderation")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    rules
                    enforcement
                    contact
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Community guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { if onAgree != nil { agreeBar } }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(onAgree == nil ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    private var intro: some View {
        Text("This is a space to talk Valorant esports. Keep it civil. Posting means you agree to these rules and to zero tolerance for abusive or objectionable content.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "The rules")
            rule("hand.raised.slash", "No harassment, hate, or threats — toward players, teams, or each other.")
            rule("nosign", "No spam, scams, or off-topic self-promotion.")
            rule("eye.slash", "No graphic, illegal, or NSFW content.")
            rule("person.2.slash", "No impersonation or doxxing.")
        }
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text).font(.subheadline)
            Spacer(minLength: 0)
        }
    }

    private var enforcement: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "How we moderate")
            Text("Report any post from its menu (•••) and it's flagged for review; enough reports auto-hide it. Block a user to stop seeing their posts. We review flagged content and remove violations, typically within 24 hours.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var contact: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Contact moderators")
            if let contactURL {
                Link(destination: contactURL) {
                    Label(Self.contactEmail, systemImage: "envelope")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Text("Reach us for appeals, urgent removals, or to report someone you can't reach in-app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var agreeBar: some View {
        Button {
            onAgree?()
            dismiss()
        } label: {
            Text("I agree — let me post")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(Theme.background)
        }
        .padding(16)
        .background(.bar)
    }
}
