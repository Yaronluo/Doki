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
        XCTAssertTrue(app.staticTexts["Bangumi 热门"].exists)
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
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(app.buttons["hero-next"].hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertNotEqual(page.value as? String, first)
        capture("carousel-manual-reduced-light")
        print("REDUCED_MATTE_ASSERTIONS_PASSED")
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
