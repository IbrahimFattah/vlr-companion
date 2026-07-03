import SwiftUI

/// Navigable reference to a thread, for full-screen presentation.
struct DiscussionRoute: Hashable {
    let scope: String
    let ref: String
    var title: String = "Discussion"
}

/// Full-screen discussion (its own scroll view + title). Inline `DiscussionView`
/// is used inside match detail; this wraps it for standalone navigation.
struct DiscussionScreen: View {
    let route: DiscussionRoute

    var body: some View {
        ScrollView {
            DiscussionView(scope: route.scope, ref: route.ref)
                .padding(16)
        }
        .background(Theme.background)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Threaded discussion for a match, event, or the general board. Rendered inline
/// (no scroll view of its own) so it can drop into an existing `ScrollView`.
struct DiscussionView: View {
    let scope: String
    let ref: String

    @Environment(AccountStore.self) private var account

    private let service = AccountService()

    @State private var posts: [ForumPost] = []
    @State private var nextCursor: Double?
    @State private var state: Loadable<Void> = .idle
    @State private var loadingMore = false

    @State private var draft = ""
    @State private var replyingTo: ForumPost?
    @State private var sending = false
    @State private var actionError: String?
    @State private var showSignIn = false
    @State private var guidelines: GuidelinesMode?
    /// First-post terms gate (App Store UGC requirement). Once accepted on this
    /// install, posting is direct; the guidelines stay reachable from the link.
    @AppStorage("acceptedCommunityGuidelines") private var acceptedGuidelines = false

    /// Why the guidelines sheet is up: a first-post gate (agree → send) or just
    /// reading them from the link.
    private enum GuidelinesMode: Identifiable {
        case gate, read
        var id: Int { self == .gate ? 0 : 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Discussion")

            if !account.isAvailable {
                unavailableCard
            } else {
                composer
                if let actionError {
                    Text(actionError).font(.caption).foregroundStyle(Theme.live)
                }
                content
            }
        }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(item: $guidelines) { mode in
            if mode == .gate {
                CommunityGuidelinesView {
                    acceptedGuidelines = true
                    Task { await send() }
                }
            } else {
                CommunityGuidelinesView(onAgree: nil)
            }
        }
        .task(id: account.authToken) { await load() }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            SkeletonColumn(count: 2)
        case .failed(let message):
            ErrorRetryView(message: message) { Task { await load() } }
        case .loaded:
            if posts.isEmpty {
                Text("No posts yet. Start the conversation.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).cardBackground()
            } else {
                ForEach(posts) { post in
                    PostRow(post: post,
                            myID: account.myUserID,
                            onUpvote: { p in Task { await upvote(p) } },
                            onReply: { p in replyingTo = p },
                            onReport: { p in Task { await report(p) } },
                            onBlock: { p in Task { await block(p) } },
                            onDelete: { p in Task { await delete(p) } })
                }
                if nextCursor != nil {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        if loadingMore { ProgressView() } else { Text("Load more") }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var unavailableCard: some View {
        Text("Discussion needs the API server. Add its URL in Settings → Data source.")
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).cardBackground()
    }

    // MARK: - Composer

    @ViewBuilder
    private var composer: some View {
        if account.isSignedIn {
            VStack(alignment: .leading, spacing: 8) {
                if let replyingTo, let name = replyingTo.author?.username {
                    HStack(spacing: 6) {
                        Text("Replying to @\(name)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button { self.replyingTo = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    TextField(replyingTo == nil ? "Add a comment…" : "Write a reply…",
                              text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button(action: attemptSend) {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                }
                Button("Community guidelines") { guidelines = .read }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .cardBackground()
        } else {
            Button { showSignIn = true } label: {
                Label("Sign in to join the discussion", systemImage: "person.crop.circle.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Data

    private func load() async {
        guard account.isAvailable else { return }
        if posts.isEmpty { state = .loading }
        do {
            let page = try await service.listPosts(scope: scope, ref: ref, token: account.authToken)
            posts = page.posts
            nextCursor = page.nextCursor
            state = .loaded(())
        } catch {
            if posts.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        if let page = try? await service.listPosts(scope: scope, ref: ref,
                                                    before: cursor, token: account.authToken) {
            posts += page.posts
            nextCursor = page.nextCursor
        }
    }

    /// Route the send button through the first-post terms gate.
    private func attemptSend() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if acceptedGuidelines {
            Task { await send() }
        } else {
            guidelines = .gate
        }
    }

    private func send() async {
        guard let token = account.authToken else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await service.createPost(scope: scope, ref: ref, body: text,
                                             parentId: replyingTo?.id, token: token)
            draft = ""
            replyingTo = nil
            actionError = nil
            await load()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func upvote(_ post: ForumPost) async {
        guard let token = account.authToken else { showSignIn = true; return }
        guard let result = try? await service.toggleUpvote(postID: post.id, token: token) else { return }
        update(post.id) { $0.upvotes = result.upvotes; $0.upvoted = result.upvoted }
    }

    private func report(_ post: ForumPost) async {
        guard let token = account.authToken else { showSignIn = true; return }
        try? await service.report(postID: post.id, reason: "", token: token)
        actionError = "Reported. Thanks — our team will review it."
    }

    private func block(_ post: ForumPost) async {
        guard let token = account.authToken, let uid = post.author?.id else { return }
        try? await service.block(userID: uid, token: token)
        await load()
    }

    private func delete(_ post: ForumPost) async {
        guard let token = account.authToken else { return }
        try? await service.deletePost(postID: post.id, token: token)
        await load()
    }

    /// Mutate a post (top-level or reply) in place by id.
    private func update(_ id: String, _ change: (inout ForumPost) -> Void) {
        for i in posts.indices {
            if posts[i].id == id { change(&posts[i]); return }
            if var replies = posts[i].replies {
                for j in replies.indices where replies[j].id == id {
                    change(&replies[j]); posts[i].replies = replies; return
                }
            }
        }
    }
}
