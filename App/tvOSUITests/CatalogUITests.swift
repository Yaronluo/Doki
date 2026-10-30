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
    func testNativeTopTabsAndHubPairing() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DOKI_LIVE_UI"] == "1", "Opt-in live network test")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-light", "--demo-hub-url", ""]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "season-bgm-")).firstMatch.waitForExistence(timeout: 35))
        let tabs = app.buttons["sparkles"]
        XCTAssertTrue(tabs.exists)
        XCTAssertLessThan(tabs.frame.minY, 120)
        XCTAssertGreaterThan(tabs.frame.minX, 450)
        Thread.sleep(forTimeInterval: 10)
        capture("native-top-tabs-full-width-light")
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
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
