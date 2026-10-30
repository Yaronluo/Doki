import Foundation
import Testing
@testable import DokiCore

@Suite("Public catalog parsing")
struct CatalogTests {
    @Test("Portrait images accept only the Bangumi image origin and upgrade HTTPS")
    func imageOrigin() {
        #expect(CatalogSubject.approvedImage("http://lain.bgm.tv/pic/cover/l/test.jpg")?.scheme == "https")
        #expect(CatalogSubject.approvedImage("https://lain.bgm.tv.evil.example/test.jpg") == nil)
        #expect(CatalogSubject.approvedImage("https://user:password@lain.bgm.tv/test.jpg") == nil)
        #expect(CatalogSubject.approvedImage("http://127.0.0.1/test.jpg") == nil)
        #expect(CatalogSubject.approvedImage("https://lain.bgm.tv:8888/test.jpg") == nil)
    }
    @Test("Bangumi episode IDs, fractional ordering and unknown duration stay distinct")
    func episode() throws {
        let data = Data(#"{"id":123,"sort":1.5,"name":"特别章节","airdate":"2026-10-01","duration":"00:24:30"}"#.utf8)
        let episode = try JSONDecoder().decode(CatalogEpisode.self, from: data).episode(subjectID: "bgm-42")
        #expect(episode.id == "bgm-ep-123")
        #expect(episode.subjectID == "bgm-42")
        #expect(episode.sort == 1.5)
        #expect(episode.durationSeconds == 1470)
        #expect(episode.availability == .unavailable) // broadcast does not prove a playable asset
        #expect(episode.airDate != nil)
    }
    @Test("Missing metadata never manufactures episode count, rating, clock time or backdrop")
    func missing() throws {
        let data = Data(#"{"id":42,"name":"原名","name_cn":"","images":{"large":"https://lain.bgm.tv/pic/cover/l/test.jpg"}}"#.utf8)
        let subject = try JSONDecoder().decode(CatalogSubject.self, from: data).subject()
        #expect(subject.title == "原名")
        #expect(subject.totalEpisodes == 0)
        #expect(subject.rating == nil)
        #expect(subject.backdropURL == nil)
        #expect(subject.backdropAsset == nil)
        #expect(subject.isRealCatalog)
        #expect(subject.broadcastTime == "时间未公布")
    }
    @Test("Repeated staff identities preserve every role and unique voice actor")
    func creditRoles() throws {
        let records = try JSONDecoder().decode([CatalogCredit].self, from: Data(#"[{"id":1,"name":"测试人员","relation":"导演","actors":[{"id":8,"name":"测试声优"}]},{"id":1,"name":"测试人员","relation":"脚本","actors":[{"id":8,"name":"测试声优"}]}]"#.utf8))
        let merged = records[0].merging(records[1])
        #expect(merged.relation == "导演 / 脚本")
        #expect(merged.actors?.count == 1)
    }
    @Test("Real public Bangumi round-trip", .enabled(if: ProcessInfo.processInfo.environment["DOKI_LIVE_METADATA"] == "1"))
    func live() async throws {
        let client = CatalogClient()
        let home = try await client.home()
        let popular = try await client.popular()
        #expect(!popular.data.isEmpty)
        #expect(popular.data.allSatisfy { $0.type == 2 && $0.nsfw != true })
        print("LIVE_POPULAR ids=\(popular.data.prefix(6).map(\.id))")
        #expect(!home.calendar.isEmpty)
        let item = try #require(home.picks.data.first)
        let detail = try await client.subject(item.id)
        #expect(detail.id == item.id)
        let episodes = try await client.episodes(item.id)
        let characters = try await client.credits(item.id, characters: true)
        let staff = try await client.credits(item.id, characters: false)
        let search = try await client.search("葬送的芙莉莲")
        #expect(!search.data.isEmpty)
        print("LIVE_CATALOG picks=\(home.picks.data.count) days=\(home.calendar.count) detail=\(detail.id) episodes=\(episodes.count) characters=\(characters.count) staff=\(staff.count) search=\(search.data.count)")
    }
}
