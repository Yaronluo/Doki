import Foundation
import Testing
@testable import DokiCore

@Suite("Demo library and progress")
struct DemoLibraryTests {
    let reference = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("Fixture subjects and episodes have stable identities")
    func stableIdentities() {
        let library = DemoLibrary(referenceDate: reference)
        #expect(library.subjects.count == 12)
        #expect(Set(library.subjects.map(\.id)).count == 12)
        #expect(library.subjects.contains { $0.title.count >= 18 })
        #expect(library.subjects.contains { $0.posterAsset == nil })
        #expect(library.subjects.contains { $0.backdropAsset == nil })

        let first = library.subjects[0]
        let episodes = library.episodes(for: first)
        #expect(episodes.count == 24)
        #expect(episodes.first?.id == "demo-subject-01-ep-01")
        #expect(episodes.last?.id == "demo-subject-01-ep-24")
        #expect(Set(episodes.map(\.id)).count == 24)
        #expect(episodes.allSatisfy { $0.durationSeconds == 1_440 })
    }

    @Test("Today separates confirmed availability from planned broadcast")
    func todayAvailability() {
        let library = DemoLibrary(referenceDate: reference)
        let today = library.todayEntries
        #expect(!today.isEmpty)
        #expect(today.contains { $0.availability == .available })
        #expect(today.contains { $0.availability != .available })

        let available = today.filter { $0.availability == .available }
        let scheduled = today.filter { $0.availability == .scheduled }
        #expect(available.count >= 2)
        #expect(scheduled.count >= 2)
        #expect(available.allSatisfy { $0.episode.number == 5 || $0.episode.number == 4 || $0.episode.number == 2 || $0.episode.number == 7 })
    }

    @Test("Continue watching excludes finished positions and keeps reverse seeks")
    func continueWatching() {
        let library = DemoLibrary(referenceDate: reference)
        var progress = library.seededProgress(referenceDate: reference)
        let continues = library.continueWatching(progress: progress)

        #expect(continues.count >= 4)
        #expect(continues.allSatisfy { $0.fraction < 0.9 })
        #expect(continues.allSatisfy { $0.subject.followState != .completed || $0.fraction < 0.9 })

        let target = continues[0]
        let rewound = max(0, target.positionSeconds - 10)
        progress.record(
            subjectID: target.subject.id,
            episodeID: target.episode.id,
            positionSeconds: rewound,
            durationSeconds: target.episode.durationSeconds,
            at: reference.addingTimeInterval(10)
        )
        let updated = library.continueWatching(progress: progress)
        #expect(updated.first?.positionSeconds == rewound)
    }

    @Test("Resume opens an almost-finished episode from the beginning")
    func resumePolicy() {
        #expect(PlaybackProgressPolicy.resumePosition(position: 300, duration: 1_440) == 300)
        #expect(PlaybackProgressPolicy.resumePosition(position: 1_400, duration: 1_440) == 0)
        #expect(PlaybackProgressPolicy.resumePosition(position: 1_440, duration: 1_440) == 0)
        #expect(PlaybackProgressPolicy.resumePosition(position: -20, duration: 1_440) == 0)
        #expect(PlaybackProgressPolicy.resumePosition(position: .nan, duration: 1_440) == 0)
        #expect(PlaybackProgressPolicy.fraction(position: 720, duration: 1_440) == 0.5)
    }

    @Test("A completed series has watched episodes without per-episode synthetic events")
    func completedSeries() {
        let library = DemoLibrary(referenceDate: reference)
        let completed = library.subjects.first { $0.followState == .completed }!
        let episode = library.episodes(for: completed)[2]
        #expect(library.isWatched(subject: completed, episode: episode, progress: ProgressBook()))

        let watching = library.subjects.first { $0.followState == .watching }!
        let watchingEpisode = library.episodes(for: watching)[0]
        #expect(!library.isWatched(subject: watching, episode: watchingEpisode, progress: ProgressBook()))
    }

    @Test("Search matches title, original title and genre")
    func search() {
        let library = DemoLibrary(referenceDate: reference)
        #expect(library.search("星海").first?.title == "星海邮差")
        #expect(library.search("stellar").first?.title == "星海邮差")
        #expect(library.search("悬疑").count >= 1)
        #expect(library.search("   ").isEmpty)
        #expect(library.search("不存在的条目").isEmpty)
    }

    @Test("Calendar window and entries remain date-only and stable")
    func calendar() {
        let library = DemoLibrary(referenceDate: reference)
        let days = library.calendarDays()
        #expect(days.count == 7)
        #expect(days[2] == Calendar.current.startOfDay(for: reference))
        let entries = library.airingEntries(on: days[2])
        #expect(entries == library.todayEntries)
        #expect(entries.allSatisfy { $0.episode.airDate != nil })
    }

    @Test("Progress book round-trips through JSON")
    func codableProgress() throws {
        let library = DemoLibrary(referenceDate: reference)
        let progress = library.seededProgress(referenceDate: reference)
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(ProgressBook.self, from: data)
        #expect(decoded == progress)
    }
}
