import SwiftUI

/// One forum post plus its (one-level) replies. The same action closures serve
/// both the top-level post and its replies — each callback receives the post it
/// applies to.
struct PostRow: View {
    let post: ForumPost
    let myID: String?
    let onUpvote: (ForumPost) -> Void
    let onReply: (ForumPost) -> Void
    let onReport: (ForumPost) -> Void
    let onBlock: (ForumPost) -> Void
    let onDelete: (ForumPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            body(for: post, isReply: false)
            if let replies = post.replies, !replies.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(replies) { reply in
                        body(for: reply, isReply: true)
                    }
                }
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Theme.elevated).frame(width: 2)
                }
            }
        }
        .padding(14)
        .cardBackground()
    }

    @ViewBuilder
    private func body(for p: ForumPost, isReply: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let author = p.author {
                    AccountAvatar(emoji: author.avatarEmoji, colorHex: author.avatarColor, size: 26)
                    Text(author.username).font(.subheadline.weight(.semibold))
                } else {
                    AccountAvatar(emoji: "🚫", colorHex: "3B4252", size: 26)
                    Text("removed").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("· \(p.date, format: .relative(presentation: .named))")
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
                if !p.removed { menu(for: p) }
            }

            Text(p.body)
                .font(.callout)
                .foregroundStyle(p.removed ? .secondary : .primary)
                .italic(p.removed)

            if !p.removed {
                HStack(spacing: 16) {
                    Button { onUpvote(p) } label: {
                        Label("\(p.upvotes)", systemImage: p.upvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(p.upvoted ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)

                    if !isReply {
                        Button { onReply(p) } label: {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func menu(for p: ForumPost) -> some View {
        Menu {
            if p.author?.id == myID {
                Button("Delete", role: .destructive) { onDelete(p) }
            } else {
                Button { onReport(p) } label: { Label("Report", systemImage: "flag") }
                Button(role: .destructive) { onBlock(p) } label: {
                    Label("Block user", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 20)
        }
    }
}
