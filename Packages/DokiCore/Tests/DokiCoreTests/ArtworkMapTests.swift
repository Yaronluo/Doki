import Foundation
import Testing
@testable import DokiCore

@Suite("Public artwork map")
struct ArtworkMapTests {
    @Test("Season and film identities, title logos and manual absence remain explicit")
    func parse() throws {
        let table = "# bangumi-tmdb-map v1\n42\ttv/90\t/Hero.jpg\t\tauto\t\to=ja ja=/Original.png:2.3 zh=/Chinese.png:3.4\n43\tmovie/91\t/Movie.jpg\t\tmanual\n44\t\t\t\tmanual\n"
        let result = try ArtworkMapParser.parse(table)
        #expect(result[42]?.mediaType == "tv")
        #expect(result[42]?.logoPath == "/Chinese.png")
        #expect(result[43]?.mediaType == "movie")
        #expect(result[44]?.backdropURL == nil)
        #expect(result[44]?.manual == true)
    }
    @Test("A poisoned mapping cannot redirect image requests to another origin")
    func reject() throws {
        #expect(ArtworkMapParser.imagePath("//127.0.0.1/private.jpg") == nil)
        #expect(ArtworkMapParser.imagePath("/../file.jpg") == nil)
        #expect(ArtworkMapParser.imagePath("/a.jpg?token=secret") == nil)
        #expect(throws: (any Error).self) { try ArtworkMapParser.parse("<html>challenge</html>") }
    }
    @Test("Real no-token backdrop and logo lookup", .enabled(if: ProcessInfo.processInfo.environment["DOKI_LIVE_METADATA"] == "1"))
    func live() async throws {
        let entry = try #require(await PublicArtworkMap.shared.lookup(554779))
        #expect(entry.backdropURL?.host == "image.tmdb.org")
        #expect(entry.logoURL != nil)
        print("LIVE_ARTWORK subject=\(entry.subjectID) kind=\(entry.mediaType) keyRequired=false backdrop=\(entry.backdropPath ?? "none")")
    }
}
