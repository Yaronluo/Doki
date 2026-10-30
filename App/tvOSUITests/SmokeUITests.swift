import XCTest

@MainActor
final class SmokeUITests: XCTestCase {
    func testExploreAccessibilityTree() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        Thread.sleep(forTimeInterval: 3)
        print("TREE_START")
        print(app.debugDescription)
        print("TREE_END")
        attach(name: "01-discover")

        XCUIRemote.shared.press(.down)
        Thread.sleep(forTimeInterval: 1)
        attach(name: "02-down")
        print("TREE_DOWN_START")
        print(app.debugDescription)
        print("TREE_DOWN_END")
    }

    func testCollapsedNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures", "--demo-dark"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["navigation-avatar"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 2)
        attach(name: "collapsed-avatar-dark")
        XCUIRemote.shared.press(.up)
        Thread.sleep(forTimeInterval: 1)
        attach(name: "after-up")
        XCTAssertTrue(app.buttons["navigation-discover"].waitForExistence(timeout: 5))
        attach(name: "expanded-matte-dark")
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(app.buttons["navigation-avatar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["navigation-discover"].exists)
        XCUIRemote.shared.press(.left)
        XCTAssertTrue(app.buttons["navigation-discover"].waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.down)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.buttons["navigation-library"].hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["我的追番"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["navigation-avatar"].exists)
        attach(name: "frosted-library-dark")
        print("NAVIGATION_ASSERTIONS_PASSED")
        app.terminate()
    }

    func testColoredBackgroundAndFocusedSegments() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures", "--demo-dark", "--demo-tab", "library", "--demo-reduce-motion"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["library-filter-all"].waitForExistence(timeout: 15))
        for _ in 0..<6 {
            if app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "library-filter-")).firstMatch.exists { break }
            XCUIRemote.shared.press(app.buttons["navigation-avatar"].hasFocus ? .down : .up)
        }
        let focused = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "library-filter-")).firstMatch
        XCTAssertTrue(focused.exists)
        attach(name: "library-filter-focused-dark")
        XCUIRemote.shared.press(.right)
        Thread.sleep(forTimeInterval: 0.4)
        let watching = app.buttons["library-filter-watching"]
        XCTAssertTrue(watching.hasFocus)
        XCTAssertLessThan(watching.frame.height, 80, "Focus must not add an oversized system plate")
        XCTAssertLessThanOrEqual(app.buttons["library-filter-all"].frame.maxX, watching.frame.minX)
        XCTAssertLessThanOrEqual(watching.frame.maxX, app.buttons["library-filter-today"].frame.minX)
        attach(name: "library-filter-watching-dark")
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.up)
        XCTAssertTrue(app.buttons["navigation-library"].waitForExistence(timeout: 5))
        attach(name: "navigation-color-translucency-dark")
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(app.buttons["navigation-avatar"].waitForExistence(timeout: 5))
        print("COLORED_BACKGROUND_FOCUS_ASSERTIONS_PASSED")
        app.terminate()
    }

    func testCalendarAndSettingsFocusedControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures", "--demo-dark", "--demo-tab", "calendar", "--demo-reduce-motion"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["navigation-avatar"].waitForExistence(timeout: 15))
        for _ in 0..<6 {
            if app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "calendar-day-")).firstMatch.exists { break }
            XCUIRemote.shared.press(app.buttons["navigation-avatar"].hasFocus ? .down : .up)
        }
        let day = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "calendar-day-")).firstMatch
        XCTAssertTrue(day.exists)
        XCTAssertLessThan(day.frame.height, 115)
        attach(name: "calendar-focused-day-dark")
        XCUIRemote.shared.press(.right)
        attach(name: "calendar-focused-next-day-dark")
        app.terminate()
        app.launchArguments = ["--demo-fixtures", "--demo-light", "--demo-tab", "profile", "--demo-reduce-motion"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["settings-row-Doki Hub"].waitForExistence(timeout: 15))
        for _ in 0..<6 {
            if app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "settings-row-")).firstMatch.exists { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "settings-row-")).firstMatch.exists)
        attach(name: "settings-focused-row-light")
        print("CALENDAR_SETTINGS_FOCUS_ASSERTIONS_PASSED")
        app.terminate()
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
