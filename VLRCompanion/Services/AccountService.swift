import Foundation

enum AccountError: LocalizedError {
    case unavailable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "No account server configured. Set the API server URL in Settings."
        case .server(let message): message
        }
    }
}

/// HTTP client for the accounts + forums API (`api-server/`). Stateless — the
/// caller passes the bearer token; `AccountStore` owns token lifecycle.
struct AccountService: Sendable {
    struct LoginResult: Decodable { let token: String; let user: Account }
    struct UpvoteResult: Decodable { let upvotes: Int; let upvoted: Bool }
    struct FavoritesResult: Codable { let favorite: String?; let secondaries: [String] }

    // MARK: - Auth + profile

    func devLogin(username: String, emoji: String, color: String) async throws -> LoginResult {
        try await request("auth/dev", method: "POST", token: nil,
                          body: ["username": username, "avatarEmoji": emoji, "avatarColor": color])
    }

    func me(token: String) async throws -> Account {
        try await request("me", token: token)
    }

    func updateProfile(token: String, username: String?, emoji: String?, color: String?) async throws -> Account {
        var body: [String: String] = [:]
        if let username { body["username"] = username }
        if let emoji { body["avatarEmoji"] = emoji }
        if let color { body["avatarColor"] = color }
        return try await request("me", method: "PATCH", token: token, body: body)
    }

    func deleteAccount(token: String) async throws {
        try await requestVoid("me", method: "DELETE", token: token)
    }

    func getFavorites(token: String) async throws -> FavoritesResult {
        try await request("me/favorites", token: token)
    }

    func putFavorites(token: String, favorite: String?, secondaries: [String]) async throws {
        struct Body: Encodable { let favorite: String?; let secondaries: [String] }
        try await requestVoid("me/favorites", method: "PUT", token: token,
                              body: Body(favorite: favorite, secondaries: secondaries))
    }

    // MARK: - Forums

    func listPosts(scope: String, ref: String, limit: Int = 20,
                   before: Double? = nil, token: String?) async throws -> ThreadPage {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before { items.append(URLQueryItem(name: "before", value: String(before))) }
        return try await request("threads/\(scope)/\(ref)/posts", token: token, query: items)
    }

    func createPost(scope: String, ref: String, body: String,
                    parentId: String?, token: String) async throws -> ForumPost {
        struct Body: Encodable { let body: String; let parentId: String? }
        return try await request("threads/\(scope)/\(ref)/posts", method: "POST", token: token,
                                 body: Body(body: body, parentId: parentId))
    }

    func toggleUpvote(postID: String, token: String) async throws -> UpvoteResult {
        try await request("posts/\(postID)/upvote", method: "POST", token: token,
                          body: [String: String]())
    }

    func report(postID: String, reason: String, token: String) async throws {
        try await requestVoid("posts/\(postID)/report", method: "POST", token: token,
                              body: ["reason": reason])
    }

    func deletePost(postID: String, token: String) async throws {
        try await requestVoid("posts/\(postID)", method: "DELETE", token: token)
    }

    func block(userID: String, token: String) async throws {
        try await requestVoid("users/\(userID)/block", method: "POST", token: token)
    }

    // MARK: - Transport

    private func makeRequest(_ path: String, method: String, token: String?,
                             query: [URLQueryItem]) throws -> URLRequest {
        guard let base = AppConfig.accountsBaseURL else { throw AccountError.unavailable }
        var components = URLComponents(url: base.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw AccountError.unavailable }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func run(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AccountError.server("No response") }
        guard (200..<300).contains(http.statusCode) else {
            throw AccountError.server(Self.detail(from: data) ?? "Request failed (\(http.statusCode))")
        }
        return data
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET",
                                       token: String? = nil,
                                       query: [URLQueryItem] = []) async throws -> T {
        let req = try makeRequest(path, method: method, token: token, query: query)
        return try JSONDecoder().decode(T.self, from: try await run(req))
    }

    private func request<T: Decodable, B: Encodable>(_ path: String, method: String,
                                                     token: String?, body: B,
                                                     query: [URLQueryItem] = []) async throws -> T {
        var req = try makeRequest(path, method: method, token: token, query: query)
        req.httpBody = try JSONEncoder().encode(body)
        return try JSONDecoder().decode(T.self, from: try await run(req))
    }

    private func requestVoid(_ path: String, method: String, token: String?) async throws {
        _ = try await run(try makeRequest(path, method: method, token: token, query: []))
    }

    private func requestVoid<B: Encodable>(_ path: String, method: String,
                                           token: String?, body: B) async throws {
        var req = try makeRequest(path, method: method, token: token, query: [])
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await run(req)
    }

    /// FastAPI error bodies look like `{"detail": "..."}` (string or array).
    private static func detail(from data: Data) -> String? {
        struct Err: Decodable { let detail: String? }
        return (try? JSONDecoder().decode(Err.self, from: data))?.detail
    }
}
