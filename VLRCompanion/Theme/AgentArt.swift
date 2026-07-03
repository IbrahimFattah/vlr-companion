import Foundation

/// Bucket-hosted agent portraits, mirroring `MapArt`. Icons come from the
/// assets bucket (`AppConfig.assetsBaseURL`) once it's populated; until then
/// there's no portrait and callers fall back to the agent's name label.
///   {bucket}/agents/{agent-slug}.png
enum AgentArt {
    /// Portrait URL for an agent name, or nil when no bucket is set. Slug folds
    /// to lowercase alphanumerics ("KAY/O" → "kayo", "Killjoy" → "killjoy").
    static func imageURL(for agent: String) -> URL? {
        guard let base = AppConfig.assetsBaseURL else { return nil }
        let slug = agent.lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
        guard !slug.isEmpty else { return nil }
        return base.appendingPathComponent("agents/\(slug).png")
    }
}
