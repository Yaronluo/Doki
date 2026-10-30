import Foundation

/// Self-made fixture content for the tvOS interaction prototype.
///
/// Everything in this file is invented for Doki. It is not Bangumi, TMDB or a
/// provider response, and it must never be presented as real catalog data.
public struct DemoLibrary: Sendable {
    public let referenceDate: Date
    public var subjects: [Subject]
    public var episodesBySubject: [String: [Episode]]

    public init(referenceDate: Date = .now, calendar: Calendar = .current) {
        self.referenceDate = referenceDate
        let today = calendar.startOfDay(for: referenceDate)
        let todayWeekday = calendar.component(.weekday, from: today)

        let seeds: [SubjectSeed] = [
            SubjectSeed(
                id: "demo-subject-01",
                bgmSubjectId: 900001,
                title: "星海邮差",
                originalTitle: "Stellar Postman",
                tagline: "把没能说出口的话，寄往群星。",
                synopsis: "在银河边缘的邮局，新任邮差凛每天要投递来自旧地球的信件。一次延迟了七十年的投递，让她遇见了一个只在夜晚出现的收件人。",
                year: 2026,
                season: "秋",
                genres: ["科幻", "治愈", "公路"],
                accentHex: "41D6C3",
                rating: 9.1,
                totalEpisodes: 24,
                currentEpisode: 5,
                weekdayOffset: 0,
                broadcastTime: "21:30",
                followState: .watching,
                updateState: .available,
                isSeasonPick: true,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-02",
                bgmSubjectId: 900002,
                title: "夏日回声",
                originalTitle: "Echoes of Summer",
                tagline: "那段旋律，仍在海风里。",
                synopsis: "废弃的海边音乐教室重新亮起灯。四个高中生决定在暑假结束前，完成一首没有人听过的歌。",
                year: 2026,
                season: "夏",
                genres: ["青春", "音乐", "群像"],
                accentHex: "F39A68",
                rating: 8.8,
                totalEpisodes: 12,
                currentEpisode: 7,
                weekdayOffset: -2,
                broadcastTime: "23:00",
                followState: .watching,
                updateState: .available,
                isSeasonPick: true,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-03",
                bgmSubjectId: 900003,
                title: "雾都侦探社",
                originalTitle: "Detective Club in the Mist",
                tagline: "每一场雾，都藏着一个名字。",
                synopsis: "在被终年海雾覆盖的港城，侦探社只接一种委托：寻找从记忆里消失的人。新来的助手却发现，自己的名字也在失踪名单上。",
                year: 2026,
                season: "秋",
                genres: ["悬疑", "都市", "推理"],
                accentHex: "7C8EA8",
                rating: 8.6,
                totalEpisodes: 12,
                currentEpisode: 6,
                weekdayOffset: 0,
                broadcastTime: "22:00",
                followState: .watching,
                updateState: .scheduled,
                isSeasonPick: false,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-04",
                bgmSubjectId: 900004,
                title: "小宇宙厨房",
                originalTitle: "Little Cosmic Kitchen",
                tagline: "今天也认真吃饭。",
                synopsis: "一间漂浮在轨道上的小餐馆，只营业到日出。老板娘用地球食材，招待来自各个星系的旅人。",
                year: 2026,
                season: "秋",
                genres: ["美食", "日常", "治愈"],
                accentHex: "E7C15A",
                rating: 8.9,
                totalEpisodes: 12,
                currentEpisode: 4,
                weekdayOffset: 0,
                broadcastTime: "19:00",
                followState: .watching,
                updateState: .available,
                isSeasonPick: true,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-05",
                bgmSubjectId: 900005,
                title: "北境列车",
                originalTitle: "The Northbound Line",
                tagline: "一直向北，直到冬天结束。",
                synopsis: "一列没有终点站的夜行列车，载着想去北方的人。乘务员弥生必须在天亮前，替每位乘客找到他们真正要去的地方。",
                year: 2025,
                season: "冬",
                genres: ["冒险", "剧情", "奇幻"],
                accentHex: "97B7D8",
                rating: 9.3,
                totalEpisodes: 12,
                currentEpisode: 12,
                weekdayOffset: -3,
                broadcastTime: "20:30",
                followState: .completed,
                updateState: .available,
                isSeasonPick: false,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-06",
                bgmSubjectId: 900006,
                title: "月光图书馆",
                originalTitle: "Moonlight Library",
                tagline: "借走一个故事，归还一段人生。",
                synopsis: "只在满月开放的图书馆，收藏着所有未完成的故事。管理员答应帮少女找回哥哥留下的最后一页。",
                year: 2026,
                season: "秋",
                genres: ["奇幻", "剧情", "书本"],
                accentHex: "9C8BE8",
                rating: 8.7,
                totalEpisodes: 12,
                currentEpisode: 3,
                weekdayOffset: -5,
                broadcastTime: "21:00",
                followState: .watching,
                updateState: .available,
                isSeasonPick: true,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-07",
                bgmSubjectId: 900007,
                title: "风之庭院",
                originalTitle: "Garden of Winds",
                tagline: "风经过的地方，花会记得。",
                synopsis: "一座会随季风移动的庭院，住着负责照料它的见习园艺师。她要在第一场雪前，让最后一批花开放。",
                year: 2027,
                season: "冬",
                genres: ["治愈", "奇幻", "自然"],
                accentHex: "88C99A",
                rating: nil,
                totalEpisodes: 12,
                currentEpisode: 1,
                weekdayOffset: 2,
                broadcastTime: "19:30",
                followState: .planned,
                updateState: .scheduled,
                isSeasonPick: false,
                hasPoster: false,
                hasBackdrop: false
            ),
            SubjectSeed(
                id: "demo-subject-08",
                bgmSubjectId: 900008,
                title: "深海信号",
                originalTitle: "Signal from the Deep",
                tagline: "海面之下，有人正在回答。",
                synopsis: "深海观测站收到一段重复了三十年的求救信号。值班员发现，信号里的声音和自己一模一样。",
                year: 2026,
                season: "秋",
                genres: ["科幻", "悬疑", "惊悚"],
                accentHex: "3E9DC9",
                rating: 8.5,
                totalEpisodes: 12,
                currentEpisode: 2,
                weekdayOffset: 0,
                broadcastTime: "23:30",
                followState: .watching,
                updateState: .available,
                isSeasonPick: false,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-09",
                bgmSubjectId: 900009,
                title: "纸飞机联盟",
                originalTitle: "Paper Plane League",
                tagline: "飞得最远的那一架，会去哪里？",
                synopsis: "全校最不擅长运动的三个人，决定用一百架纸飞机挑战屋顶。青春不需要冠军，只需要一次足够远的飞行。",
                year: 2025,
                season: "夏",
                genres: ["校园", "青春", "喜剧"],
                accentHex: "F2B35D",
                rating: 8.4,
                totalEpisodes: 12,
                currentEpisode: 12,
                weekdayOffset: -1,
                broadcastTime: "18:30",
                followState: .completed,
                updateState: .available,
                isSeasonPick: false,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-10",
                bgmSubjectId: 900010,
                title: "深夜电台 24:00",
                originalTitle: "Midnight Radio 24:00",
                tagline: "睡不着的人，请把频道调到最后一格。",
                synopsis: "城市入夜后，只有一档没有节目表的电台仍在播音。主播读听众来信，也读那些还没有发生的故事。",
                year: 2026,
                season: "秋",
                genres: ["都市", "群像", "治愈"],
                accentHex: "D77A9A",
                rating: 9.0,
                totalEpisodes: 12,
                currentEpisode: 7,
                weekdayOffset: 0,
                broadcastTime: "24:00",
                followState: .watching,
                updateState: .available,
                isSeasonPick: true,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-11",
                bgmSubjectId: 900011,
                title: "机械与麦穗",
                originalTitle: "Machines and Wheat",
                tagline: "当最后一台收割机学会做梦。",
                synopsis: "农业机器人被留在废弃农场里，等待一场不会再来的丰收。一个路过的少年教会它，如何自己决定季节。",
                year: 2027,
                season: "春",
                genres: ["科幻", "田园", "剧情"],
                accentHex: "B7C46B",
                rating: nil,
                totalEpisodes: 12,
                currentEpisode: 1,
                weekdayOffset: 3,
                broadcastTime: "20:00",
                followState: .planned,
                updateState: .scheduled,
                isSeasonPick: false,
                hasPoster: true,
                hasBackdrop: true
            ),
            SubjectSeed(
                id: "demo-subject-12",
                bgmSubjectId: 900012,
                title: "雨停之前，请把这封没有寄出的信读给风听",
                originalTitle: "Before the Rain Ends, Read This Unsent Letter to the Wind",
                tagline: "有些话，必须在下雨的时候说。",
                synopsis: "雨季来临的第七天，邮局收到一封没有地址的信。送信人沿着海岸线出发，替陌生人完成一次迟到了十年的告别。",
                year: 2026,
                season: "秋",
                genres: ["剧情", "公路", "治愈"],
                accentHex: "7DA8C8",
                rating: 8.9,
                totalEpisodes: 12,
                currentEpisode: 5,
                weekdayOffset: 0,
                broadcastTime: "22:30",
                followState: .watching,
                updateState: .scheduled,
                isSeasonPick: false,
                hasPoster: true,
                hasBackdrop: false
            )
        ]

        let episodeTitlePool = [
            "启程", "回声", "未寄出的信", "夜航", "潮汐", "远方的灯",
            "海风与旧唱片", "第七个夏天", "没有终点的站台", "风经过的庭院",
            "在群星之间", "雨停之前", "昨天的人", "逆光", "小行星厨房",
            "月光的借阅卡", "静止的时钟", "北纬四十度", "纸飞机", "深夜来电",
            "空白的节目单", "穿过雾", "最后一班车", "明天见"
        ]

        var builtSubjects: [Subject] = []
        var builtEpisodes: [String: [Episode]] = [:]

        for (index, seed) in seeds.enumerated() {
            let accent = seed.accentHex
            let subject = Subject(
                id: seed.id,
                bgmSubjectId: seed.bgmSubjectId,
                title: seed.title,
                originalTitle: seed.originalTitle,
                tagline: seed.tagline,
                synopsis: seed.synopsis,
                year: seed.year,
                season: seed.season,
                genres: seed.genres,
                posterAsset: seed.hasPoster ? String(format: "poster-%02d", index + 1) : nil,
                backdropAsset: seed.hasBackdrop ? String(format: "backdrop-%02d", index + 1) : nil,
                accentHex: accent,
                rating: seed.rating,
                totalEpisodes: seed.totalEpisodes,
                weekday: Self.weekday(
                    relativeTo: todayWeekday,
                    offset: seed.weekdayOffset
                ),
                broadcastTime: seed.broadcastTime,
                followState: seed.followState,
                updateState: seed.updateState,
                isSeasonPick: seed.isSeasonPick
            )

            let airtime = Self.date(
                onWeekday: subject.weekday,
                time: subject.broadcastTime,
                referenceDate: referenceDate,
                calendar: calendar
            )

            var episodes: [Episode] = []
            for number in 1...subject.totalEpisodes {
                let airDate = calendar.date(
                    byAdding: .day,
                    value: (number - seed.currentEpisode) * 7,
                    to: airtime
                )

                let availability: Episode.Availability
                if subject.followState == .completed {
                    availability = .available
                } else if number < seed.currentEpisode {
                    availability = .available
                } else if number == seed.currentEpisode {
                    let isToday = calendar.isDate(airtime, inSameDayAs: referenceDate)
                    if isToday && subject.updateState != .available {
                        availability = .scheduled
                    } else {
                        availability = .available
                    }
                } else {
                    availability = .scheduled
                }

                let episode = Episode(
                    id: "\(subject.id)-ep-\(String(format: "%02d", number))",
                    bgmEpisodeId: subject.bgmSubjectId * 100 + number,
                    subjectID: subject.id,
                    number: number,
                    sort: Double(number),
                    title: episodeTitlePool[(number - 1 + index * 3) % episodeTitlePool.count],
                    synopsis: "第 \(number) 话。自造章节简介，用于验证 TV 的选集、焦点与播放交互；不代表真实剧情。",
                    durationSeconds: 24 * 60,
                    airDate: airDate,
                    availability: availability
                )
                episodes.append(episode)
            }

            builtSubjects.append(subject)
            builtEpisodes[subject.id] = episodes
        }

        self.subjects = builtSubjects
        self.episodesBySubject = builtEpisodes
    }

    public var allEpisodes: [Episode] {
        episodesBySubject.values.flatMap { $0 }.sorted {
            if $0.subjectID == $1.subjectID { return $0.sort < $1.sort }
            return $0.subjectID < $1.subjectID
        }
    }

    public func subject(id: String) -> Subject? {
        subjects.first { $0.id == id }
    }

    public func episode(id: String) -> Episode? {
        allEpisodes.first { $0.id == id }
    }

    public func episodes(for subject: Subject) -> [Episode] {
        episodesBySubject[subject.id] ?? []
    }

    public func episodes(forSubjectID id: String) -> [Episode] {
        episodesBySubject[id] ?? []
    }

    public var seasonPicks: [Subject] {
        subjects.filter(\.isSeasonPick)
    }

    public var watchingSubjects: [Subject] {
        subjects.filter { $0.followState == .watching }
    }

    public var todayEntries: [AiringEntry] {
        airingEntries(on: referenceDate)
    }

    public func airingEntries(on date: Date, calendar: Calendar = .current) -> [AiringEntry] {
        var entries: [AiringEntry] = []
        for subject in subjects {
            for episode in episodes(for: subject) {
                guard let airDate = episode.airDate,
                      calendar.isDate(airDate, inSameDayAs: date) else { continue }
                entries.append(
                    AiringEntry(
                        subject: subject,
                        episode: episode,
                        airDate: airDate,
                        availability: episode.availability
                    )
                )
            }
        }
        return entries.sorted {
            if $0.availability != $1.availability {
                return $0.availability == .available
            }
            if $0.airDate != $1.airDate { return $0.airDate < $1.airDate }
            return $0.subject.title.localizedStandardCompare($1.subject.title) == .orderedAscending
        }
    }

    public func calendarDays(
        before: Int = 2,
        after: Int = 4,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = calendar.startOfDay(for: referenceDate)
        return (-before...after).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
    }

    public func search(_ query: String) -> [Subject] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = Self.folded(trimmed)
        return subjects.filter { subject in
            let haystack = [
                subject.title,
                subject.originalTitle,
                subject.tagline,
                subject.genres.joined(separator: " ")
            ].joined(separator: " ")
            return Self.folded(haystack).contains(needle)
        }
    }

    public func continueWatching(progress: ProgressBook) -> [ContinueWatchingItem] {
        progress.recent.compactMap { position -> ContinueWatchingItem? in
            guard !position.isFinished,
                  let subject = subject(id: position.subjectID),
                  let episode = episode(id: position.episodeID),
                  episode.availability == .available else { return nil }
            return ContinueWatchingItem(
                subject: subject,
                episode: episode,
                positionSeconds: position.positionSeconds,
                updatedAt: position.updatedAt
            )
        }
    }

    public func seededProgress(referenceDate: Date = .now) -> ProgressBook {
        let seeds: [(subjectIndex: Int, episodeNumber: Int, position: Double, hoursAgo: Double)] = [
            (0, 5, 312, 2.5),
            (1, 7, 900, 26),
            (3, 4, 1_180, 48),
            (5, 3, 62, 5),
            (7, 2, 30, 1.2),
            (9, 7, 721, 8),
            (4, 12, 1_420, 72)
        ]

        var book = ProgressBook()
        for seed in seeds {
            let subject = subjects[seed.subjectIndex]
            let episode = episodes(for: subject)[seed.episodeNumber - 1]
            book.record(
                subjectID: subject.id,
                episodeID: episode.id,
                positionSeconds: seed.position,
                durationSeconds: episode.durationSeconds,
                sourceID: DemoSources.all[0].id,
                at: referenceDate.addingTimeInterval(-seed.hoursAgo * 3_600)
            )
        }
        return book
    }

    public func nextEpisode(for subject: Subject, progress: ProgressBook) -> Episode? {
        guard let latest = progress.latestPosition(forSubject: subject.id),
              let latestEpisode = episode(id: latest.episodeID) else {
            return episodes(for: subject).first { $0.availability == .available }
        }

        if !latest.isFinished, latestEpisode.availability == .available {
            return latestEpisode
        }

        return episodes(for: subject).first {
            $0.number > latestEpisode.number && $0.availability == .available
        }
    }

    public func isWatched(
        subject: Subject,
        episode: Episode,
        progress: ProgressBook
    ) -> Bool {
        if subject.followState == .completed, episode.availability == .available {
            return true
        }
        return progress.position(for: episode.id)?.isFinished == true
    }

    private static func weekday(relativeTo todayWeekday: Int, offset: Int) -> Int {
        let value = (todayWeekday - 1 + offset) % 7
        return (value + 7) % 7 + 1
    }

    private static func date(
        onWeekday weekday: Int,
        time: String,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date {
        let today = calendar.startOfDay(for: referenceDate)
        let todayWeekday = calendar.component(.weekday, from: today)
        var delta = weekday - todayWeekday
        if delta > 0 { delta -= 7 }

        let day = calendar.date(byAdding: .day, value: delta, to: today) ?? today
        let parts = time.split(separator: ":").compactMap { Int($0) }
        let hour = parts.count > 0 ? parts[0] : 20
        let minute = parts.count > 1 ? parts[1] : 0
        return calendar.date(
            bySettingHour: hour % 24,
            minute: minute,
            second: 0,
            of: day
        ) ?? day
    }

    private static func folded(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: locale
        )
    }

    private static let locale = Locale(identifier: "zh_Hans_CN")
}

private struct SubjectSeed: Sendable {
    let id: String
    let bgmSubjectId: Int
    let title: String
    let originalTitle: String
    let tagline: String
    let synopsis: String
    let year: Int
    let season: String
    let genres: [String]
    let accentHex: String
    let rating: Double?
    let totalEpisodes: Int
    let currentEpisode: Int
    let weekdayOffset: Int
    let broadcastTime: String
    let followState: Subject.FollowState
    let updateState: Subject.UpdateState
    let isSeasonPick: Bool
    let hasPoster: Bool
    let hasBackdrop: Bool
}
