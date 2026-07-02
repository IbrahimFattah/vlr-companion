import Foundation

/// A signed-in user. Mirrors the api-server `user` shape.
struct Account: Codable, Hashable, Identifiable {
    let id: String
    var username: String
    var avatarEmoji: String
    var avatarColor: String
}

/// A forum post (or reply). `replies` is populated only for top-level posts in
/// a thread listing.
struct ForumPost: Codable, Hashable, Identifiable {
    let id: String
    let scope: String
    let ref: String
    let parentId: String?
    var body: String
    let createdAt: Double
    var removed: Bool
    var author: Author?
    var upvotes: Int
    var upvoted: Bool
    var replyCount: Int
    var replies: [ForumPost]?

    struct Author: Codable, Hashable {
        let id: String
        let username: String
        let avatarEmoji: String
        let avatarColor: String
    }

    var date: Date { Date(timeIntervalSince1970: createdAt) }
}

/// One page of a thread.
struct ThreadPage: Codable {
    let posts: [ForumPost]
    let nextCursor: Double?
}
