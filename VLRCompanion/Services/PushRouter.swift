import Foundation
import Observation

/// Deep-link target set when the user taps a push notification. Observed at the
/// tab-bar level: tapping a "match live / finished" alert switches to Home and
/// pushes that match's detail screen.
///
/// A tapped push only carries a thin `match` payload, not a full detail object.
/// That's enough — `MatchDetailView.currentMatch` upgrades a stub Match with
/// live detail once `matchDetail(id:)` loads, so routing from a cold tap works.
@Observable
final class PushRouter {
    static let shared = PushRouter()

    /// The match a notification wants to open. Consumed (set back to nil) by
    /// `HomeView` once it pushes the detail screen.
    var pendingMatch: Match?

    private init() {}

    /// Called from the notification delegate (main actor) with a decoded
    /// payload. No-op if the payload has no routable match.
    func handle(userInfo: [AnyHashable: Any]) {
        guard let match = Match.fromPushPayload(userInfo) else { return }
        pendingMatch = match
    }
}

extension Match {
    /// Builds a stub `Match` from a push `userInfo` dictionary. Returns nil when
    /// there's no `match` object or it lacks the fields needed to navigate.
    ///
    /// Expected shape (see `push-server/apns.py`):
    /// ```
    /// { "match": { "id": "123", "team1": "Sentinels", "tag1": "SEN",
    ///              "team2": "Fnatic", "tag2": "FNC", "event": "...",
    ///              "stage": "...", "status": "live",
    ///              "score1": 1, "score2": 0,
    ///              "color1": "FF4655", "color2": "FF6600",
    ///              "logo1": "https://...", "logo2": "https://..." } }
    /// ```
    static func fromPushPayload(_ userInfo: [AnyHashable: Any]) -> Match? {
        guard let m = userInfo["match"] as? [AnyHashable: Any],
              let id = (m["id"] as? String) ?? (m["id"] as? Int).map(String.init),
              !id.isEmpty else { return nil }

        func str(_ key: String) -> String { (m[key] as? String) ?? "" }
        func intVal(_ key: String) -> Int? {
            if let i = m[key] as? Int { return i }
            if let s = m[key] as? String { return Int(s) }
            return nil
        }
        func url(_ key: String) -> URL? {
            guard let s = m[key] as? String, !s.isEmpty else { return nil }
            return URL(string: s)
        }

        let team1 = Team(id: "push:\(str("tag1"))",
                         name: str("team1").isEmpty ? "Team 1" : str("team1"),
                         tag: str("tag1").isEmpty ? "T1" : str("tag1"),
                         region: .americas,
                         colorHex: str("color1").isEmpty ? "3B4252" : str("color1"),
                         logoURL: url("logo1"))
        let team2 = Team(id: "push:\(str("tag2"))",
                         name: str("team2").isEmpty ? "Team 2" : str("team2"),
                         tag: str("tag2").isEmpty ? "T2" : str("tag2"),
                         region: .americas,
                         colorHex: str("color2").isEmpty ? "3B4252" : str("color2"),
                         logoURL: url("logo2"))

        let status = MatchStatus(rawValue: str("status")) ?? .live

        return Match(id: id,
                     eventName: str("event"),
                     stage: str("stage"),
                     team1: team1,
                     team2: team2,
                     score1: intVal("score1"),
                     score2: intVal("score2"),
                     status: status,
                     time: Date(),
                     format: .unknown,
                     currentMap: nil,
                     streamURL: nil,
                     vodURL: nil)
    }
}
