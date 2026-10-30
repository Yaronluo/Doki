import XCTest

@MainActor
final class CatalogUITests: XCTestCase {
    func testLiveCatalogDetailAndReturn() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DOKI_LIVE_UI"] == "1", "Opt-in live network test")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", ""]
        app.launch()
        app.activate()
        let poster = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "season-bgm-")).firstMatch
        XCTAssertTrue(poster.waitForExistence(timeout: 35), "Bangumi posters must replace the fixture catalog")
        Thread.sleep(forTimeInterval: 8)
        capture("live-discover-dark")
        print("CATALOG_HOME_TREE\n\(app.debugDescription)")
        for _ in 0..<8 {
            let current = app.buttons.matching(NSPredicate(format: "hasFocus == true")).firstMatch
            if current.exists && current.identifier.hasPrefix("season-bgm-") { break }
            XCUIRemote.shared.press(.down)
            Thread.sleep(forTimeInterval: 0.4)
        }
        let focused = app.buttons.matching(NSPredicate(format: "hasFocus == true")).firstMatch
        XCTAssertTrue(focused.identifier.hasPrefix("season-bgm-"))
        let posterID = focused.identifier
        XCUIRemote.shared.press(.select)
        Thread.sleep(forTimeInterval: 1)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["加入追番"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 8)
        capture("live-detail-dark")
        print("CATALOG_DETAIL_TREE\n\(app.debugDescription)")
        XCTAssertFalse(app.staticTexts["自造条目"].exists)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons[posterID].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 2)
        capture("live-return")
        print("CATALOG_RETURN_FOCUS \(app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.identifier)")
        print("CATALOG_UI_ASSERTIONS_PASSED")
        app.terminate()
    }
    func testLiveLightCalendarSearchAndSettings() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DOKI_LIVE_UI"] == "1", "Opt-in live network test")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-light", "--demo-hub-url", "", "--demo-tab", "calendar", "--demo-reduce-motion", "--demo-reduce-transparency"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-bgm-")).firstMatch.waitForExistence(timeout: 35))
        Thread.sleep(forTimeInterval: 7); capture("live-calendar-light-reduced")
        app.terminate()
        app.launchArguments = ["--demo-light", "--demo-hub-url", "", "--demo-tab", "search", "--demo-search-query", "葬送的芙莉莲"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-bgm-")).firstMatch.waitForExistence(timeout: 35))
        Thread.sleep(forTimeInterval: 7); capture("live-search-light")
        app.terminate()
        app.launchArguments = ["--demo-light", "--demo-route", "hub", "--demo-reduce-transparency", "--demo-reduce-motion"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["保存并检查"].waitForExistence(timeout: 15))
        capture("hub-settings-light-reduced")
        print("CATALOG_LIGHT_ASSERTIONS_PASSED")
        app.terminate()
    }
    func testHubFailureKeepsCatalog() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DOKI_LIVE_UI"] == "1", "Opt-in live network test")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", ""]
        app.launch(); app.activate()
        let posters = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "season-bgm-"))
        XCTAssertTrue(posters.firstMatch.waitForExistence(timeout: 35))
        app.terminate()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", "http://127.0.0.1:9"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["重试"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "season-bgm-")).firstMatch.exists)
        capture("hub-failure-preserves-catalog")
        print("CATALOG_FAILURE_ASSERTIONS_PASSED")
        app.terminate()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", ""]
        app.launch(); app.activate()
        app.terminate()
    }
    func testCollapsedNavigationAndHubPairing() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DOKI_LIVE_UI"] == "1", "Opt-in live network test")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-light", "--demo-hub-url", ""]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "season-bgm-")).firstMatch.waitForExistence(timeout: 35))
        let avatar = app.buttons["navigation-avatar"]
        XCTAssertTrue(avatar.exists)
        XCTAssertLessThan(avatar.frame.minY, 120)
        XCTAssertLessThan(avatar.frame.minX, 160)
        XCTAssertFalse(app.buttons["sparkles"].exists)
        Thread.sleep(forTimeInterval: 10)
        capture("collapsed-navigation-full-width-light")
        app.terminate()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", "http://127.0.0.1:18080", "--demo-route", "auth"]
        app.launch(); app.activate()
        XCTAssertTrue(app.staticTexts["pairing-code"].waitForExistence(timeout: 20))
        capture("real-hub-tv-pairing")
        app.terminate()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", ""]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "season-bgm-")).firstMatch.waitForExistence(timeout: 35))
    }
    func testPopularCarouselAndMenuPause() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DOKI_LIVE_UI"] == "1", "Opt-in live network test")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", "http://127.0.0.1:18080"]
        app.launch(); app.activate()
        let page = app.otherElements["hero-page"]
        XCTAssertTrue(page.waitForExistence(timeout: 35))
        XCTAssertFalse(app.staticTexts["Bangumi 热门"].exists)
        XCTAssertFalse(app.buttons["sparkles"].exists)
        let first = try XCTUnwrap(page.value as? String)
        capture("popular-carousel-dark")
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", first), object: page)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 45), .completed)
        capture("popular-carousel-next")
        let beforeMenu = page.value as? String
        XCUIRemote.shared.press(.up)
        XCTAssertTrue(app.buttons["navigation-discover"].waitForExistence(timeout: 5))
        capture("popular-matte-navigation-dark")
        Thread.sleep(forTimeInterval: 9)
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(app.buttons["navigation-avatar"].waitForExistence(timeout: 5))
        XCTAssertEqual(page.value as? String, beforeMenu, "Opening the menu must pause automatic rotation")
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: app.buttons["hero-primary"])
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 4), .completed, "Closing the menu restores content focus")
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.select)
        Thread.sleep(forTimeInterval: 1)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["加入追番"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 3)
        capture("popular-detail-flat-controls")
        XCTAssertFalse(app.buttons["navigation-avatar"].exists)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["hero-primary"].waitForExistence(timeout: 8))
        capture("popular-detail-return")
        for _ in 0..<4 { XCUIRemote.shared.press(.down) }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "season-bgm-")).firstMatch.exists)
        capture("discover-shelf-colored-background")
        print("POPULAR_CAROUSEL_ASSERTIONS_PASSED")
        app.terminate()
    }

    func testReducedMatteNavigationAndManualCarousel() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures", "--demo-light", "--demo-reduce-motion", "--demo-reduce-transparency"]
        app.launch(); app.activate()
        let page = app.otherElements["hero-page"]
        XCTAssertTrue(page.waitForExistence(timeout: 15))
        let first = page.value as? String
        Thread.sleep(forTimeInterval: 9)
        XCTAssertEqual(page.value as? String, first)
        capture("carousel-reduced-light")
        XCUIRemote.shared.press(.up)
        XCTAssertTrue(app.buttons["navigation-discover"].waitForExistence(timeout: 5))
        capture("navigation-solid-reduced-light")
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(app.buttons["navigation-avatar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hero-primary"].hasFocus)
        XCUIRemote.shared.press(.right)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", first ?? ""), object: page)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        capture("carousel-manual-reduced-light")
        print("REDUCED_MATTE_ASSERTIONS_PASSED")
        app.terminate()
    }

    func testShelfPreviewAndCapsule() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures", "--demo-dark", "--demo-reduce-motion"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["hero-primary"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["hero-primary"].label, "立即播放")
        XCTAssertFalse(app.staticTexts["继续观看"].exists, "Logged-out users must not see the resume shelf")
        XCTAssertFalse(app.buttons["hero-previous"].exists)
        XCTAssertFalse(app.buttons["hero-next"].exists)
        XCTAssertFalse(app.staticTexts["向右返回内容"].exists)
        capture("home-play-capsule-dark")
        let page = app.otherElements["hero-page"]
        let initialPage = page.value as? String
        for _ in 0..<8 {
            if app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "season-")).firstMatch.exists { break }
            XCUIRemote.shared.press(.down)
            Thread.sleep(forTimeInterval: 0.3)
        }
        let poster = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "season-")).firstMatch
        XCTAssertTrue(poster.exists)
        let posterID = poster.identifier
        capture("shelf-before-selection-dark")
        XCUIRemote.shared.press(.select)
        let preview = app.descendants(matching: .any)["shelf-preview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(app.buttons[posterID].hasFocus, "Preview keeps the selected poster focused")
        XCTAssertEqual(page.value as? String, initialPage, "Shelf preview must not replace the top carousel")
        capture("shelf-geometry-final")
        XCTAssertLessThan(preview.frame.minY, 180)
        XCTAssertGreaterThan(app.buttons[posterID].frame.minY, preview.frame.minY + 300)
        capture("shelf-expanded-dark")
        XCTAssertFalse(app.buttons["navigation-avatar"].exists, "Capsule hides while browsing lower content")
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "加入追番", "已加入追番")).firstMatch.waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons[posterID].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(app.buttons[posterID].hasFocus)
        XCUIRemote.shared.press(.menu)
        XCTAssertFalse(preview.exists)
        for _ in 0..<10 {
            if app.buttons["navigation-discover"].exists { break }
            XCUIRemote.shared.press(.left)
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(app.buttons["navigation-discover"].waitForExistence(timeout: 5), "Left edge opens the menu with the capsule hidden")
        capture("capsule-expanded-dark")
        XCUIRemote.shared.press(.right)
        XCTAssertFalse(app.buttons["navigation-discover"].exists)
        app.terminate()
    }

    func testLiveHomeAndShelfPreview() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DOKI_LIVE_UI"] == "1", "Opt-in live network test")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-dark", "--demo-hub-url", ""]
        app.launch()
        let posters = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "season-bgm-"))
        XCTAssertTrue(posters.firstMatch.waitForExistence(timeout: 40))
        Thread.sleep(forTimeInterval: 8)
        capture("live-home-final-dark")
        for _ in 0..<8 {
            if app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "season-bgm-")).firstMatch.exists { break }
            XCUIRemote.shared.press(.down)
            Thread.sleep(forTimeInterval: 0.3)
        }
        let selected = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "season-bgm-")).firstMatch
        XCTAssertTrue(selected.exists)
        let selectedID = selected.identifier
        capture("live-shelf-before-final-dark")
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.descendants(matching: .any)["shelf-preview"].firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 6)
        XCTAssertTrue(app.buttons[selectedID].hasFocus)
        capture("live-shelf-expanded-final-dark")
        for _ in 0..<10 {
            if app.buttons["navigation-discover"].exists { break }
            XCUIRemote.shared.press(.left)
        }
        XCTAssertTrue(app.buttons["navigation-discover"].waitForExistence(timeout: 5))
        capture("live-capsule-expanded-final-dark")
        XCUIRemote.shared.press(.right)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(app.buttons[selectedID].hasFocus)
        app.terminate()
    }

    func testAnimatedShelfFocusAndCancellation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures", "--demo-dark"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["hero-primary"].waitForExistence(timeout: 15))
        let focusedPoster = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "season-")).firstMatch
        for _ in 0..<8 {
            if focusedPoster.exists { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(focusedPoster.exists)
        let firstID = focusedPoster.identifier
        XCUIRemote.shared.press(.select)
        XCUIRemote.shared.press(.menu)
        let preview = app.descendants(matching: .any)["shelf-preview"].firstMatch
        XCTAssertTrue(preview.waitForNonExistence(timeout: 5), "Return during entry cancels all pending tracks")
        XCTAssertTrue(app.buttons[firstID].hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        capture("animated-shelf-open")
        let oldValue = preview.value as? String
        XCUIRemote.shared.press(.right)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", oldValue ?? ""), object: preview)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed, "Hero follows focus without a second preview confirmation")
        let secondID = focusedPoster.identifier
        XCTAssertNotEqual(secondID, firstID)
        capture("animated-shelf-next-focus")
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "加入追番", "已加入追番")).firstMatch.waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: app.buttons[secondID])
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 4), .completed)
        capture("animated-detail-return-hero")
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(preview.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons[secondID].hasFocus)
        capture("animated-shelf-restored")
        app.terminate()
    }

    func testShelfVerticalNavigationAndVisibleFocus() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures", "--demo-dark"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["hero-primary"].waitForExistence(timeout: 15))
        let season = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "season-")).firstMatch
        for _ in 0..<8 {
            if season.exists { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(season.exists)
        let previousID = season.identifier
        XCUIRemote.shared.press(.right)
        Thread.sleep(forTimeInterval: 0.6)
        let selectedID = season.identifier
        XCTAssertNotEqual(previousID, selectedID)
        XCTAssertEqual(selectedID, "season-demo-subject-02", "One Right command advances exactly one card")
        XCTAssertGreaterThan(app.buttons[selectedID].frame.width, app.buttons[previousID].frame.width * 1.10,
                             "The focused poster must be visibly larger than its neighbor")
        capture("poster-focus-size-and-outline")
        XCUIRemote.shared.press(.select)
        let preview = app.descendants(matching: .any)["shelf-preview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertLessThan(app.buttons[selectedID].frame.minY, 650, "The shelf belongs immediately below the summary")
        XCTAssertLessThan(app.buttons[selectedID].frame.maxY, 1050, "The entire enlarged card must remain visible")
        capture("spring-shelf-open")
        XCUIRemote.shared.press(.down)
        let today = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "today-")).firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 5), "Down reaches the following shelf in hero mode")
        capture("spring-shelf-next-row")
        XCUIRemote.shared.press(.up)
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: app.buttons[selectedID])
        let restoration = XCTWaiter.wait(for: [restored], timeout: 5)
        capture("spring-shelf-previous-row")
        if restoration != .completed {
            print("VERTICAL_FOCUS", app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex.map(\.identifier))
            print("VERTICAL_PREVIEW", preview.value ?? "missing")
        }
        XCTAssertEqual(restoration, .completed, "Up restores the preceding row and column")
        XCUIRemote.shared.press(.up)
        let hero = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: app.buttons["hero-primary"])
        let heroRestoration = XCTWaiter.wait(for: [hero], timeout: 5)
        capture("spring-shelf-hero-focus")
        if heroRestoration != .completed {
            print("HERO_FOCUS", app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex.map(\.identifier))
            print("HERO_FRAME", app.buttons["hero-primary"].frame)
        }
        XCTAssertEqual(heroRestoration, .completed, "Up from the first shelf returns to the carousel")
        XCTAssertTrue(preview.waitForNonExistence(timeout: 5))
        capture("spring-shelf-closed-up")
        app.terminate()
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
