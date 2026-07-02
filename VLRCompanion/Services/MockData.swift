import Foundation

/// Deterministic sample data. The schedule is rebuilt relative to `Date.now`
/// on every fetch, so Live / Upcoming / Results are always populated no
/// matter when the app runs. Everything derives from seeded hashes, so the
/// same match always shows the same score, maps, and agents.
enum MockData {

    // MARK: - Teams (ordered roughly strongest-first per region; rankings reuse this order)

    static let teams: [Team] = [
        // Americas
        Team(id: "sen", name: "Sentinels", tag: "SEN", region: .americas, colorHex: "FA4454"),
        Team(id: "g2", name: "G2 Esports", tag: "G2", region: .americas, colorHex: "C8CDD6"),
        Team(id: "loud", name: "LOUD", tag: "LOUD", region: .americas, colorHex: "2CE66C"),
        Team(id: "lev", name: "Leviatán", tag: "LEV", region: .americas, colorHex: "79D7F7"),
        Team(id: "nrg", name: "NRG", tag: "NRG", region: .americas, colorHex: "B7BDC8"),
        Team(id: "100t", name: "100 Thieves", tag: "100T", region: .americas, colorHex: "EA3224"),
        Team(id: "c9", name: "Cloud9", tag: "C9", region: .americas, colorHex: "00AEEF"),
        Team(id: "kru", name: "KRÜ Esports", tag: "KRÜ", region: .americas, colorHex: "FF66C4"),
        Team(id: "mibr", name: "MIBR", tag: "MIBR", region: .americas, colorHex: "11B76A"),
        Team(id: "eg", name: "Evil Geniuses", tag: "EG", region: .americas, colorHex: "1B6FBF"),
        // EMEA
        Team(id: "fnc", name: "Fnatic", tag: "FNC", region: .emea, colorHex: "FF5900"),
        Team(id: "th", name: "Team Heretics", tag: "TH", region: .emea, colorHex: "B08428"),
        Team(id: "tl", name: "Team Liquid", tag: "TL", region: .emea, colorHex: "2E5BFF"),
        Team(id: "navi", name: "Natus Vincere", tag: "NAVI", region: .emea, colorHex: "F7E13D"),
        Team(id: "vit", name: "Team Vitality", tag: "VIT", region: .emea, colorHex: "E2FF3D"),
        Team(id: "kc", name: "Karmine Corp", tag: "KC", region: .emea, colorHex: "00CCFF"),
        Team(id: "fut", name: "FUT Esports", tag: "FUT", region: .emea, colorHex: "E11D48"),
        Team(id: "bbl", name: "BBL Esports", tag: "BBL", region: .emea, colorHex: "8B5CF6"),
        Team(id: "gx", name: "GIANTX", tag: "GX", region: .emea, colorHex: "5F6CFF"),
        Team(id: "m8", name: "Gentle Mates", tag: "M8", region: .emea, colorHex: "FF7AB6"),
        // Pacific
        Team(id: "prx", name: "Paper Rex", tag: "PRX", region: .pacific, colorHex: "FF4FA3"),
        Team(id: "geng", name: "Gen.G", tag: "GEN", region: .pacific, colorHex: "AA8B30"),
        Team(id: "drx", name: "DRX", tag: "DRX", region: .pacific, colorHex: "1348F5"),
        Team(id: "t1", name: "T1", tag: "T1", region: .pacific, colorHex: "E2012D"),
        Team(id: "zeta", name: "ZETA DIVISION", tag: "ZETA", region: .pacific, colorHex: "DDE3EA"),
        Team(id: "rrq", name: "Rex Regum Qeon", tag: "RRQ", region: .pacific, colorHex: "F5A623"),
        Team(id: "dfm", name: "DetonatioN FocusMe", tag: "DFM", region: .pacific, colorHex: "2F6BFF"),
        Team(id: "ge", name: "Global Esports", tag: "GE", region: .pacific, colorHex: "1BB6E8"),
        Team(id: "tln", name: "Talon Esports", tag: "TLN", region: .pacific, colorHex: "E23C2E"),
        Team(id: "ts", name: "Team Secret", tag: "TS", region: .pacific, colorHex: "9AA3AF"),
        // China
        Team(id: "edg", name: "EDward Gaming", tag: "EDG", region: .china, colorHex: "DF2E2E"),
        Team(id: "blg", name: "Bilibili Gaming", tag: "BLG", region: .china, colorHex: "FB7299"),
        Team(id: "te", name: "Trace Esports", tag: "TE", region: .china, colorHex: "8E4DFF"),
        Team(id: "wol", name: "Wolves Esports", tag: "WOL", region: .china, colorHex: "FF7A00"),
        Team(id: "fpx", name: "FunPlus Phoenix", tag: "FPX", region: .china, colorHex: "FF5117"),
        Team(id: "nova", name: "Nova Esports", tag: "NOVA", region: .china, colorHex: "35D0BA"),
        Team(id: "drg", name: "Dragon Ranger Gaming", tag: "DRG", region: .china, colorHex: "2ECC71"),
        Team(id: "tyl", name: "TYLOO", tag: "TYL", region: .china, colorHex: "D42127"),
    ]

    static func team(_ id: String) -> Team? {
        teams.first { $0.id == id }
    }

    static let mapPool = ["Ascent", "Bind", "Haven", "Lotus", "Sunset", "Abyss", "Corrode"]

    static let comps: [[String]] = [
        ["Jett", "Omen", "Sova", "Killjoy", "Breach"],
        ["Raze", "Astra", "Fade", "Cypher", "Gekko"],
        ["Neon", "Viper", "Sova", "Chamber", "KAY/O"],
        ["Jett", "Clove", "Fade", "Killjoy", "Tejo"],
        ["Waylay", "Omen", "Skye", "Vyse", "Iso"],
        ["Raze", "Viper", "Gekko", "Deadlock", "Sova"],
        ["Yoru", "Astra", "Breach", "Cypher", "Skye"],
    ]

    // MARK: - Seeding

    static func seed(_ string: String) -> UInt64 {
        string.utf8.reduce(5381 as UInt64) { ($0 &* 33) &+ UInt64($1) }
    }

    private static func pick<T>(_ array: [T], _ seed: UInt64, salt: UInt64) -> T {
        array[Int((seed &+ salt &* 7919) % UInt64(array.count))]
    }

    // MARK: - Schedule

    private static func eventName(for region: Region) -> String {
        "VCT 2026: \(region.displayName) Stage 2"
    }

    /// Three matches are always live "right now" so the ticker, haptics, and
    /// per-map live states can be exercised at any time of day.
    static func liveMatches(now: Date) -> [Match] {
        let fnc = team("fnc")!, th = team("th")!
        let sen = team("sen")!, t100 = team("100t")!
        let edg = team("edg")!, blg = team("blg")!
        return [
            Match(id: "live-fnc-th", eventName: eventName(for: .emea), stage: "Regular Season · Week 3",
                  team1: fnc, team2: th, score1: 1, score2: 0, status: .live,
                  time: now.addingTimeInterval(-70 * 60), format: .bo3, currentMap: "Ascent",
                  streamURL: URL(string: "https://www.twitch.tv/valorant_emea")),
            Match(id: "live-sen-100t", eventName: eventName(for: .americas), stage: "Regular Season · Week 3",
                  team1: sen, team2: t100, score1: 0, score2: 0, status: .live,
                  time: now.addingTimeInterval(-25 * 60), format: .bo3, currentMap: "Lotus",
                  streamURL: URL(string: "https://www.twitch.tv/valorant_americas")),
            Match(id: "live-edg-blg", eventName: eventName(for: .china), stage: "Regular Season · Week 3",
                  team1: edg, team2: blg, score1: 1, score2: 1, status: .live,
                  time: now.addingTimeInterval(-100 * 60), format: .bo3, currentMap: "Sunset",
                  streamURL: URL(string: "https://www.twitch.tv/valorantesports_cn")),
        ]
    }

    /// The single canonical match pool: every tab, event, and team profile
    /// filters this list, so IDs stay consistent across screens.
    static func allMatches(now: Date = .now) -> [Match] {
        var pool = liveMatches(now: now)
        let calendar = Calendar.current

        for region in Region.allCases {
            let regionTeams = teams.filter { $0.region == region }
            let n = regionTeams.count
            let event = eventName(for: region)

            for dayOffset in -12...6 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                      let firstSlot = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)
                else { continue }

                for slot in 0..<2 {
                    let time = firstSlot.addingTimeInterval(Double(slot) * 3 * 3600)
                    // Leave a window around "now" clear so the forced live
                    // matches are the only in-progress games.
                    if abs(time.timeIntervalSince(now)) < 2.5 * 3600 { continue }

                    let k = dayOffset + 40
                    let regionSalt = Int(seed(region.rawValue) % 1000)
                    let i = (k * 2 + slot * 5 + regionSalt) % n
                    var j = (i + 1 + (k + slot) % (n - 1)) % n
                    if i == j { j = (j + 1) % n }

                    let id = "m-\(region.rawValue)-\(k)-\(slot)"
                    let matchSeed = seed(id)
                    let completed = time < now
                    let week = min(3, max(1, (dayOffset + 12) / 7 + 1))

                    var score1: Int?
                    var score2: Int?
                    if completed {
                        let team1Wins = matchSeed % 2 == 0
                        let loserMaps = Int((matchSeed >> 3) % 2)
                        score1 = team1Wins ? 2 : loserMaps
                        score2 = team1Wins ? loserMaps : 2
                    }

                    pool.append(Match(
                        id: id, eventName: event, stage: "Regular Season · Week \(week)",
                        team1: regionTeams[i], team2: regionTeams[j],
                        score1: score1, score2: score2,
                        status: completed ? .completed : .upcoming,
                        time: time, format: .bo3, currentMap: nil,
                        streamURL: completed ? nil : URL(string: "https://www.twitch.tv/valorant"),
                        vodURL: completed ? URL(string: "https://www.youtube.com/@valorantesports") : nil))
                }
            }
        }

        pool.append(contentsOf: internationalResults(now: now))
        return pool
    }

    /// Completed international events so Events → Completed has real brackets.
    private static func internationalResults(now: Date) -> [Match] {
        func completed(_ id: String, _ event: String, _ stage: String, _ t1: String, _ t2: String,
                       _ s1: Int, _ s2: Int, daysAgo: Double, format: MatchFormat = .bo3) -> Match {
            Match(id: id, eventName: event, stage: stage,
                  team1: team(t1)!, team2: team(t2)!, score1: s1, score2: s2,
                  status: .completed, time: now.addingTimeInterval(-daysAgo * 86400),
                  format: format, currentMap: nil, streamURL: nil,
                  vodURL: URL(string: "https://www.youtube.com/@valorantesports"))
        }
        let london = "Valorant Masters London 2026"
        let santiago = "Valorant Masters Santiago 2026"
        return [
            completed("ml-gf", london, "Playoffs · Grand Final", "fnc", "prx", 3, 1, daysAgo: 11, format: .bo5),
            completed("ml-sf1", london, "Playoffs · Semifinal", "fnc", "g2", 2, 0, daysAgo: 12),
            completed("ml-sf2", london, "Playoffs · Semifinal", "prx", "edg", 2, 1, daysAgo: 12.2),
            completed("ml-qf1", london, "Playoffs · Quarterfinal", "geng", "t1", 2, 1, daysAgo: 13),
            completed("ml-qf2", london, "Playoffs · Quarterfinal", "g2", "sen", 2, 1, daysAgo: 13.2),
            completed("ms-gf", santiago, "Playoffs · Grand Final", "tl", "geng", 3, 2, daysAgo: 108, format: .bo5),
            completed("ms-sf1", santiago, "Playoffs · Semifinal", "tl", "edg", 2, 0, daysAgo: 109),
            completed("ms-sf2", santiago, "Playoffs · Semifinal", "geng", "sen", 2, 1, daysAgo: 109.2),
        ]
    }

    // MARK: - Match detail

    static func detail(for match: Match) -> MatchDetail {
        let matchSeed = seed(match.id)
        let mapCount = mapPool.count
        let start = Int(matchSeed % UInt64(mapCount))
        let step = 1 + Int((matchSeed >> 4) % UInt64(mapCount - 1))
        // mapCount is prime, so any nonzero step visits every map exactly once.
        let names = (0..<mapCount).map { mapPool[(start + $0 * step) % mapCount] }

        let t1 = match.team1.tag
        let t2 = match.team2.tag
        let series = match.format.mapsToWin * 2 - 1

        var vetos: [String] = []
        if match.format == .bo5 {
            vetos = ["\(t1) ban \(names[5])", "\(t2) ban \(names[6])",
                     "\(t1) pick \(names[0])", "\(t2) pick \(names[1])",
                     "\(t1) pick \(names[2])", "\(t2) pick \(names[3])",
                     "\(names[4]) remains"]
        } else {
            vetos = ["\(t1) ban \(names[3])", "\(t2) ban \(names[4])",
                     "\(t1) pick \(names[0])", "\(t2) pick \(names[1])",
                     "\(t1) ban \(names[5])", "\(t2) ban \(names[6])",
                     "\(names[2]) remains"]
        }

        func agents(_ mapIndex: Int, home: Bool) -> [String] {
            let offset = home ? 0 : 3
            return comps[Int((matchSeed &+ UInt64(mapIndex * 2 + offset)) % UInt64(comps.count))]
        }

        func completedMap(_ index: Int, team1Won: Bool) -> MapResult {
            // Regulation: first to 13. Overtime: tied 12–12, win by 2.
            let overtime = (matchSeed >> UInt64(index * 2)) % 9 == 0
            let loserScore = overtime
                ? 12 + Int((matchSeed >> UInt64(index * 3 + 2)) % 3)
                : 3 + Int((matchSeed >> UInt64(index * 3 + 2)) % 9)
            let winnerScore = overtime ? loserScore + 2 : 13
            let pickedBy = index == series - 1 ? "DECIDER" : (index % 2 == 0 ? t1 : t2)
            return MapResult(name: names[index],
                             score1: team1Won ? winnerScore : loserScore,
                             score2: team1Won ? loserScore : winnerScore,
                             status: .completed, pickedBy: pickedBy,
                             agents1: agents(index, home: true),
                             agents2: agents(index, home: false))
        }

        /// Winner sequence for the played maps: loser's map wins land on the
        /// even series positions (2nd, 4th), which reads naturally for Bo3/Bo5.
        func winnerSequence(_ wins1: Int, _ wins2: Int) -> [Bool] {
            let team1Leads = wins1 >= wins2
            let leaderCount = max(wins1, wins2)
            let trailerCount = min(wins1, wins2)
            var sequence: [Bool] = []
            var leaderLeft = leaderCount, trailerLeft = trailerCount
            while leaderLeft + trailerLeft > 0 {
                if sequence.count % 2 == 0, leaderLeft > 0 {
                    sequence.append(team1Leads); leaderLeft -= 1
                } else if trailerLeft > 0 {
                    sequence.append(!team1Leads); trailerLeft -= 1
                } else {
                    sequence.append(team1Leads); leaderLeft -= 1
                }
            }
            return sequence
        }

        var maps: [MapResult] = []
        var headToHead: String?
        let lead = 3 + Int(matchSeed % 5)
        let trail = 1 + Int((matchSeed >> 6) % 3)
        headToHead = "\(t1) lead the head-to-head \(lead)–\(min(trail, lead - 1)) over the last year"

        switch match.status {
        case .upcoming:
            // Veto happens shortly before start; only show it inside 24 h.
            if match.time.timeIntervalSinceNow > 24 * 3600 { vetos = [] }
            maps = []

        case .completed:
            let sequence = winnerSequence(match.score1 ?? 0, match.score2 ?? 0)
            maps = sequence.enumerated().map { completedMap($0.offset, team1Won: $0.element) }

        case .live:
            let played = (match.score1 ?? 0) + (match.score2 ?? 0)
            let sequence = winnerSequence(match.score1 ?? 0, match.score2 ?? 0)
            maps = sequence.enumerated().map { completedMap($0.offset, team1Won: $0.element) }
            let liveScoreA = 5 + Int(matchSeed % 8)
            let liveScoreB = max(0, liveScoreA - 1 - Int((matchSeed >> 5) % 5))
            let team1Attacking = matchSeed % 2 == 0
            maps.append(MapResult(name: match.currentMap ?? names[played],
                                  score1: team1Attacking ? liveScoreA : liveScoreB,
                                  score2: team1Attacking ? liveScoreB : liveScoreA,
                                  status: .live,
                                  pickedBy: played % 2 == 0 ? t1 : t2,
                                  agents1: agents(played, home: true),
                                  agents2: agents(played, home: false)))
            let remaining = series - maps.count
            if remaining > 0, (match.score1 ?? 0) + 1 < match.format.mapsToWin || (match.score2 ?? 0) + 1 < match.format.mapsToWin {
                for index in maps.count..<min(series, maps.count + remaining) {
                    maps.append(MapResult(name: names[index], score1: 0, score2: 0,
                                          status: .upcoming,
                                          pickedBy: index == series - 1 ? "DECIDER" : (index % 2 == 0 ? t1 : t2),
                                          agents1: [], agents2: []))
                }
            }
        }

        return MatchDetail(match: match, maps: maps, vetos: vetos, headToHead: headToHead)
    }

    // MARK: - Events

    static let eventNameByID: [String: String] = [
        "ev-s2-americas": "VCT 2026: Americas Stage 2",
        "ev-s2-emea": "VCT 2026: EMEA Stage 2",
        "ev-s2-pacific": "VCT 2026: Pacific Stage 2",
        "ev-s2-china": "VCT 2026: China Stage 2",
        "masters-london": "Valorant Masters London 2026",
        "masters-santiago": "Valorant Masters Santiago 2026",
    ]

    static func events() -> [VLREvent] {
        [
            VLREvent(id: "ev-s2-americas", name: "VCT 2026: Americas Stage 2", region: "Americas",
                     status: .ongoing, dates: "Jun 17 – Jul 27", prizePool: "$250,000"),
            VLREvent(id: "ev-s2-emea", name: "VCT 2026: EMEA Stage 2", region: "EMEA",
                     status: .ongoing, dates: "Jun 17 – Jul 27", prizePool: "$250,000"),
            VLREvent(id: "ev-s2-pacific", name: "VCT 2026: Pacific Stage 2", region: "Pacific",
                     status: .ongoing, dates: "Jun 17 – Jul 27", prizePool: "$250,000"),
            VLREvent(id: "ev-s2-china", name: "VCT 2026: China Stage 2", region: "China",
                     status: .ongoing, dates: "Jun 17 – Jul 27", prizePool: "$250,000"),
            VLREvent(id: "champions-2026", name: "Valorant Champions 2026", region: "International",
                     status: .upcoming, dates: "Sep 10 – Oct 4", prizePool: "$2,500,000"),
            VLREvent(id: "ewc-2026", name: "Esports World Cup 2026", region: "International",
                     status: .upcoming, dates: "Jul 15 – 20", prizePool: "$1,000,000"),
            VLREvent(id: "playoffs-americas", name: "VCT 2026: Americas Stage 2 Playoffs", region: "Americas",
                     status: .upcoming, dates: "Aug 1 – 10", prizePool: "$250,000"),
            VLREvent(id: "masters-london", name: "Valorant Masters London 2026", region: "International",
                     status: .completed, dates: "Jun 5 – 21", prizePool: "$1,000,000"),
            VLREvent(id: "masters-santiago", name: "Valorant Masters Santiago 2026", region: "International",
                     status: .completed, dates: "Mar 6 – 15", prizePool: "$500,000"),
        ]
    }

    static func eventMatches(eventID: String, now: Date = .now) -> [Match] {
        guard let name = eventNameByID[eventID] else { return [] }
        return allMatches(now: now)
            .filter { $0.eventName == name }
            .sorted { $0.time > $1.time }
    }

    // MARK: - Rankings

    static func rankings(region: Region) -> [TeamRanking] {
        let regionTeams = teams.filter { $0.region == region }
        return regionTeams.enumerated().map { index, team in
            let teamSeed = seed(team.id + "-rank")
            return TeamRanking(rank: index + 1,
                               team: team,
                               points: 748 - index * 42 - Int(teamSeed % 17),
                               movement: Int(teamSeed % 7) - 3,
                               record: "\(16 - index)–\(4 + index)")
        }
    }

    // MARK: - Rosters

    private static let knownRosters: [String: [Player]] = [
        "sen": [
            Player(id: "sen-1", handle: "zekken", realName: "Zachary Patrone", country: "🇺🇸", role: "Duelist"),
            Player(id: "sen-2", handle: "johnqt", realName: "Mohamed Ouarid", country: "🇲🇦", role: "IGL"),
            Player(id: "sen-3", handle: "N4RRATE", realName: "Marshall Massey", country: "🇺🇸", role: "Initiator"),
            Player(id: "sen-4", handle: "bang", realName: "Sean Bezerra", country: "🇺🇸", role: "Controller"),
            Player(id: "sen-5", handle: "Zellsis", realName: "Jordan Montemurro", country: "🇺🇸", role: "Sentinel"),
        ],
        "fnc": [
            Player(id: "fnc-1", handle: "Boaster", realName: "Jake Howlett", country: "🇬🇧", role: "IGL"),
            Player(id: "fnc-2", handle: "Derke", realName: "Nikita Sirmitev", country: "🇫🇮", role: "Duelist"),
            Player(id: "fnc-3", handle: "Alfajer", realName: "Emir Beder", country: "🇹🇷", role: "Sentinel"),
            Player(id: "fnc-4", handle: "Chronicle", realName: "Timofey Khromov", country: "🇷🇺", role: "Flex"),
            Player(id: "fnc-5", handle: "Leo", realName: "Leo Jannesson", country: "🇸🇪", role: "Initiator"),
        ],
        "prx": [
            Player(id: "prx-1", handle: "f0rsakeN", realName: "Jason Susanto", country: "🇮🇩", role: "Flex"),
            Player(id: "prx-2", handle: "Jinggg", realName: "Wang Jing Jie", country: "🇸🇬", role: "Duelist"),
            Player(id: "prx-3", handle: "d4v41", realName: "Khalish Rusyaidee", country: "🇲🇾", role: "Initiator"),
            Player(id: "prx-4", handle: "mindfreak", realName: "Aaron Leonhart", country: "🇮🇩", role: "Controller"),
            Player(id: "prx-5", handle: "something", realName: "Ilya Petrov", country: "🇷🇺", role: "Duelist"),
        ],
        "drx": [
            Player(id: "drx-1", handle: "stax", realName: "Kim Gu-taek", country: "🇰🇷", role: "IGL"),
            Player(id: "drx-2", handle: "MaKo", realName: "Kim Myeong-gwan", country: "🇰🇷", role: "Controller"),
            Player(id: "drx-3", handle: "BuZz", realName: "Yu Byung-chul", country: "🇰🇷", role: "Duelist"),
            Player(id: "drx-4", handle: "Rb", realName: "Goo Sang-min", country: "🇰🇷", role: "Initiator"),
            Player(id: "drx-5", handle: "Flashback", realName: "Cho Min-hyuk", country: "🇰🇷", role: "Sentinel"),
        ],
        "loud": [
            Player(id: "loud-1", handle: "saadhak", realName: "Matias Delipetro", country: "🇦🇷", role: "IGL"),
            Player(id: "loud-2", handle: "Less", realName: "Felipe Basso", country: "🇧🇷", role: "Sentinel"),
            Player(id: "loud-3", handle: "cauanzin", realName: "Cauan Pereira", country: "🇧🇷", role: "Initiator"),
            Player(id: "loud-4", handle: "tuyz", realName: "Arthur Vieira", country: "🇧🇷", role: "Controller"),
            Player(id: "loud-5", handle: "qck", realName: "Gabriel Lima", country: "🇧🇷", role: "Duelist"),
        ],
        "g2": [
            Player(id: "g2-1", handle: "valyn", realName: "Jacob Batio", country: "🇺🇸", role: "IGL"),
            Player(id: "g2-2", handle: "leaf", realName: "Nathan Orf", country: "🇺🇸", role: "Duelist"),
            Player(id: "g2-3", handle: "trent", realName: "Trent Cairns", country: "🇨🇦", role: "Initiator"),
            Player(id: "g2-4", handle: "jawgemo", realName: "Alexander Mor", country: "🇰🇭", role: "Duelist"),
            Player(id: "g2-5", handle: "JonahP", realName: "Jonah Pulice", country: "🇨🇦", role: "Sentinel"),
        ],
        "edg": [
            Player(id: "edg-1", handle: "ZmjjKK", realName: "Zheng Yongkang", country: "🇨🇳", role: "Duelist"),
            Player(id: "edg-2", handle: "CHICHOO", realName: "Wan Shunzhi", country: "🇨🇳", role: "IGL"),
            Player(id: "edg-3", handle: "nobody", realName: "Wang Senxu", country: "🇨🇳", role: "Controller"),
            Player(id: "edg-4", handle: "Smoggy", realName: "Zhang Zhao", country: "🇨🇳", role: "Flex"),
            Player(id: "edg-5", handle: "S1Mon", realName: "Yu Jiaming", country: "🇨🇳", role: "Sentinel"),
        ],
    ]

    private static let handlePool = [
        "Vexa", "Rush", "Kaze", "Nyx", "Blaze", "Echoes", "Frost", "Havoc", "Lyric", "Onyx",
        "Pulse", "Quartz", "Ravn", "Sable", "Tempo", "Umbra", "Voltix", "Wisp", "Zephyr", "Drift",
        "Embr", "Falcn", "Glitch", "Hexed", "Irys", "Jolt", "Karma", "Lumen", "Mirage", "Nimbus",
        "Orbit", "Prism", "Quill", "Ronin", "Statik", "Sworn", "Undertow", "Vertex", "Warden", "Xeno",
    ]
    private static let firstNames = ["Alex", "Sam", "Kai", "Leon", "Max", "Ryu", "Jin", "Nico", "Theo", "Eli",
                                     "Mika", "Aron", "Dane", "Igor", "Yuri", "Kenta", "Minho", "Diego", "Lucas", "Pedro"]
    private static let lastNames = ["Novak", "Silva", "Tanaka", "Kim", "Costa", "Meyer", "Ivanov", "Sato", "Park", "Almeida",
                                    "Weber", "Rossi", "Dubois", "Chen", "Wang", "Lopez", "Haas", "Berg", "Fontaine", "Mori"]

    private static func flags(for region: Region) -> [String] {
        switch region {
        case .americas: ["🇺🇸", "🇧🇷", "🇨🇦", "🇦🇷", "🇨🇱"]
        case .emea: ["🇬🇧", "🇫🇷", "🇩🇪", "🇪🇸", "🇹🇷", "🇸🇪"]
        case .pacific: ["🇰🇷", "🇯🇵", "🇸🇬", "🇮🇩", "🇹🇭", "🇮🇳"]
        case .china: ["🇨🇳"]
        }
    }

    static func roster(for team: Team) -> [Player] {
        if let known = knownRosters[team.id] { return known }
        let roles = ["Duelist", "IGL", "Initiator", "Controller", "Sentinel"]
        let teamSeed = seed(team.id + "-roster")
        return (0..<5).map { index in
            let salt = UInt64(index)
            return Player(id: "\(team.id)-\(index + 1)",
                          handle: pick(handlePool, teamSeed, salt: salt),
                          realName: "\(pick(firstNames, teamSeed, salt: salt &+ 11)) \(pick(lastNames, teamSeed, salt: salt &+ 23))",
                          country: pick(flags(for: team.region), teamSeed, salt: salt &+ 5),
                          role: roles[index])
        }
    }

    static func staff(for team: Team) -> [Player] {
        let teamSeed = seed(team.id + "-staff")
        return [
            Player(id: "\(team.id)-coach",
                   handle: pick(handlePool, teamSeed, salt: 51),
                   realName: "\(pick(firstNames, teamSeed, salt: 52)) \(pick(lastNames, teamSeed, salt: 53))",
                   country: pick(flags(for: team.region), teamSeed, salt: 54),
                   role: "Head Coach"),
        ]
    }

    // MARK: - Player stats

    static func playerStats(region: Region) -> [PlayerStat] {
        func stat(_ handle: String, _ tag: String, _ country: String, _ rating: Double,
                  _ acs: Double, _ kd: Double, _ kast: Double, _ adr: Double, _ agents: [String]) -> PlayerStat {
            PlayerStat(id: "\(tag)-\(handle)".lowercased(), handle: handle, teamTag: tag, country: country,
                       rating: rating, acs: acs, kd: kd, kast: kast, adr: adr, agents: agents)
        }
        switch region {
        case .americas:
            return [
                stat("aspas", "LEV", "🇧🇷", 1.24, 258, 1.38, 73.1, 168, ["Jett", "Raze", "Neon"]),
                stat("Demon1", "NRG", "🇺🇸", 1.18, 244, 1.29, 74.0, 159, ["Jett", "Waylay"]),
                stat("zekken", "SEN", "🇺🇸", 1.16, 249, 1.24, 72.4, 161, ["Raze", "Jett", "Neon"]),
                stat("jawgemo", "G2", "🇰🇭", 1.13, 238, 1.18, 71.2, 155, ["Raze", "Gekko"]),
                stat("Cryocells", "100T", "🇺🇸", 1.12, 226, 1.27, 70.6, 146, ["Jett", "Chamber"]),
                stat("leaf", "G2", "🇺🇸", 1.11, 231, 1.20, 72.9, 151, ["Raze", "Iso"]),
                stat("Less", "LOUD", "🇧🇷", 1.10, 218, 1.16, 74.8, 142, ["Vyse", "Killjoy", "Viper"]),
                stat("kiNgg", "LEV", "🇨🇱", 1.08, 209, 1.09, 75.3, 138, ["Omen", "Astra"]),
                stat("N4RRATE", "SEN", "🇺🇸", 1.08, 221, 1.13, 72.0, 147, ["Sova", "Gekko"]),
                stat("moose", "C9", "🇨🇦", 1.06, 214, 1.10, 71.5, 141, ["Omen", "Clove"]),
                stat("Boostio", "100T", "🇺🇸", 1.04, 205, 1.05, 70.1, 134, ["Killjoy", "Cypher"]),
                stat("valyn", "G2", "🇺🇸", 0.99, 194, 0.97, 71.8, 128, ["Omen", "Brimstone"]),
            ]
        case .emea:
            return [
                stat("Derke", "FNC", "🇫🇮", 1.21, 251, 1.33, 72.7, 164, ["Jett", "Raze", "Waylay"]),
                stat("Wo0t", "TH", "🇩🇪", 1.19, 246, 1.28, 73.5, 160, ["Raze", "Iso", "Yoru"]),
                stat("Leo", "FNC", "🇸🇪", 1.15, 228, 1.25, 76.1, 149, ["Sova", "Fade", "Gekko"]),
                stat("Sayf", "VIT", "🇸🇪", 1.14, 236, 1.22, 72.3, 154, ["Jett", "Tejo"]),
                stat("MiniBoo", "TH", "🇬🇧", 1.13, 233, 1.19, 72.9, 152, ["Neon", "Raze"]),
                stat("Alfajer", "FNC", "🇹🇷", 1.12, 224, 1.21, 73.8, 147, ["Vyse", "Killjoy", "Cypher"]),
                stat("keiko", "TL", "🇧🇪", 1.10, 227, 1.15, 71.4, 148, ["Neon", "Jett"]),
                stat("Chronicle", "FNC", "🇷🇺", 1.08, 210, 1.12, 75.6, 139, ["Fade", "KAY/O", "Viper"]),
                stat("SUYGETSU", "NAVI", "🇷🇺", 1.07, 208, 1.14, 72.2, 137, ["Cypher", "Vyse"]),
                stat("Shao", "NAVI", "🇷🇺", 1.04, 203, 1.06, 74.0, 135, ["Sova", "Fade"]),
                stat("marteen", "KC", "🇫🇷", 1.03, 212, 1.08, 70.3, 140, ["Jett", "Neon"]),
                stat("Boaster", "FNC", "🇬🇧", 0.96, 182, 0.92, 72.5, 121, ["Omen", "Astra", "Clove"]),
            ]
        case .pacific:
            return [
                stat("something", "PRX", "🇷🇺", 1.22, 256, 1.34, 71.9, 167, ["Jett", "Raze", "Chamber"]),
                stat("f0rsakeN", "PRX", "🇮🇩", 1.20, 243, 1.27, 73.2, 158, ["Yoru", "Tejo", "Waylay"]),
                stat("t3xture", "GEN", "🇰🇷", 1.17, 241, 1.26, 71.0, 156, ["Jett", "Neon"]),
                stat("Jinggg", "PRX", "🇸🇬", 1.16, 239, 1.23, 72.6, 157, ["Raze", "Iso"]),
                stat("Jemkin", "RRQ", "🇷🇺", 1.15, 240, 1.25, 69.8, 158, ["Raze", "Neon"]),
                stat("MaKo", "DRX", "🇰🇷", 1.13, 219, 1.21, 76.4, 143, ["Omen", "Viper", "Astra"]),
                stat("Meteor", "GEN", "🇰🇷", 1.12, 222, 1.19, 74.9, 145, ["KAY/O", "Sova"]),
                stat("BuZz", "DRX", "🇰🇷", 1.11, 229, 1.17, 71.7, 150, ["Jett", "Raze", "Iso"]),
                stat("izu", "T1", "🇰🇷", 1.08, 217, 1.13, 72.1, 143, ["Jett", "Neon"]),
                stat("Dep", "ZETA", "🇯🇵", 1.07, 213, 1.12, 73.0, 140, ["Raze", "Neon"]),
                stat("Laz", "ZETA", "🇯🇵", 1.05, 198, 1.04, 74.6, 131, ["Cypher", "Viper"]),
                stat("stax", "DRX", "🇰🇷", 1.02, 196, 1.01, 73.4, 129, ["Breach", "KAY/O"]),
            ]
        case .china:
            return [
                stat("ZmjjKK", "EDG", "🇨🇳", 1.19, 252, 1.30, 70.8, 165, ["Jett", "Raze", "Waylay"]),
                stat("whzy", "BLG", "🇨🇳", 1.16, 245, 1.26, 71.5, 160, ["Jett", "Neon"]),
                stat("Knight", "BLG", "🇨🇳", 1.14, 230, 1.24, 73.9, 150, ["Yoru", "Iso"]),
                stat("Life", "FPX", "🇨🇳", 1.12, 233, 1.20, 72.0, 152, ["Raze", "Jett"]),
                stat("Smoggy", "TE", "🇨🇳", 1.11, 225, 1.18, 72.8, 147, ["Tejo", "Sova", "Gekko"]),
                stat("Viva", "DRG", "🇨🇳", 1.08, 219, 1.13, 71.3, 144, ["Jett", "Neon"]),
                stat("BerLIN", "WOL", "🇨🇳", 1.06, 212, 1.10, 72.4, 139, ["Raze", "Iso"]),
                stat("Yuicaw", "WOL", "🇨🇳", 1.05, 204, 1.07, 73.6, 135, ["Omen", "Astra"]),
                stat("CHICHOO", "EDG", "🇨🇳", 1.03, 197, 1.02, 74.4, 130, ["Skye", "Fade"]),
                stat("nobody", "EDG", "🇨🇳", 1.01, 191, 0.99, 73.0, 126, ["Omen", "Viper"]),
            ]
        }
    }

    // MARK: - News

    static func news(now: Date = .now) -> [NewsItem] {
        func item(_ id: String, _ title: String, _ summary: String, _ author: String, hoursAgo: Double) -> NewsItem {
            NewsItem(id: id, title: title, summary: summary, author: author,
                     date: now.addingTimeInterval(-hoursAgo * 3600),
                     url: URL(string: "https://www.vlr.gg/news"))
        }
        return [
            item("n1", "Fnatic extend unbeaten Stage 2 run with sweep of Heretics",
                 "FNC take Ascent and Lotus in under 80 minutes to move to 6–0 in the group.",
                 "VLR Staff", hoursAgo: 3),
            item("n2", "Champions 2026 Paris: schedule, qualified teams, and format",
                 "Sixteen teams, two groups, and a lower bracket that forgives exactly one mistake.",
                 "VLR Staff", hoursAgo: 9),
            item("n3", "Sentinels lock in N4RRATE through 2027",
                 "The initiator's extension ends weeks of speculation about the off-season.",
                 "VLR Staff", hoursAgo: 26),
            item("n4", "Power Rankings, July: Paper Rex reclaim the top spot",
                 "Masters London runners-up jump two places after a perfect week in Pacific.",
                 "VLR Staff", hoursAgo: 49),
            item("n5", "Patch 11.02 meta check: Tejo pick rate keeps climbing",
                 "The initiator now shows up on five of seven maps at VCT level.",
                 "VLR Staff", hoursAgo: 74),
            item("n6", "ZmjjKK on the Masters London loss: \"Paris is the answer\"",
                 "EDG's star duelist talks semifinal heartbreak and China's road to Champions.",
                 "VLR Staff", hoursAgo: 98),
        ]
    }

    // MARK: - Team profile

    static func profile(teamID: String, now: Date = .now) -> TeamProfile? {
        guard let team = team(teamID) else { return nil }
        let pool = allMatches(now: now)
        let involved = pool.filter { $0.involves(teamID) }

        let live = involved.filter { $0.status == .live }
        let upcoming = live + involved.filter { $0.status == .upcoming }.sorted { $0.time < $1.time }
        let results = involved.filter { $0.status == .completed }.sorted { $0.time > $1.time }

        let regionRankings = rankings(region: team.region)
        let ranking = regionRankings.firstIndex { $0.team.id == teamID }.map { $0 + 1 }
        let record = ranking.flatMap { regionRankings[$0 - 1].record }

        let groupPosition = ((ranking ?? 5) + 1) / 2
        let ordinals = ["1st", "2nd", "3rd", "4th", "5th"]
        let standing = "\(ordinals[min(groupPosition, 5) - 1]) · Group \((ranking ?? 1) % 2 == 0 ? "B" : "A") · \(eventName(for: team.region))"

        return TeamProfile(team: team,
                           ranking: ranking,
                           record: record,
                           roster: roster(for: team),
                           staff: staff(for: team),
                           upcoming: upcoming,
                           results: results,
                           standing: standing)
    }
}
