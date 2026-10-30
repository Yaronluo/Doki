import XCTest

final class PlayerFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo-fixtures"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        Thread.sleep(forTimeInterval: 1.5)
    }

    func testPlayerAndChromeFocus() {
        // Up reaches the native tab bar. Moving right from the focused tab
        // activates "追番" and moves focus into its first poster.
        press(.up)
        printFocus("tab")
        press(.right)
        printFocus("library-first")
        press(.right)
        printFocus("library-second")
        press(.select)
        Thread.sleep(forTimeInterval: 1.0)
        printFocus("detail")
        capture("30-detail")
        print("DETAIL_BUTTONS")
        print(app.buttons.debugDescription)
        print("END_DETAIL_BUTTONS")

        press(.select)
        Thread.sleep(forTimeInterval: 2.5)
        printFocus("player")
        print("PLAYER_TREE_START")
        print(app.debugDescription)
        print("PLAYER_TREE_END")
        capture("31-player")

        press(.playPause)
        Thread.sleep(forTimeInterval: 0.8)
        printFocus("player-paused")
        capture("32-player-paused")

        press(.playPause)
        Thread.sleep(forTimeInterval: 0.4)
        press(.up)
        printFocus("player-up-1")
        press(.up)
        printFocus("player-up-2")
        press(.up)
        printFocus("player-up-3")

        press(.menu)
        Thread.sleep(forTimeInterval: 1.0)
        printFocus("after-player-menu")
        capture("33-after-player-menu")
        print("AFTER_PLAYER_TREE_START")
        print(app.debugDescription)
        print("AFTER_PLAYER_TREE_END")
        app.terminate()
    }

    override func tearDown() {
        app?.terminate()
        app = nil
    }

    private func press(_ button: XCUIRemote.Button, delay: TimeInterval = 0.65) {
        XCUIRemote.shared.press(button)
        Thread.sleep(forTimeInterval: delay)
    }

    private func focusedElement() -> XCUIElement? {
        let match = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true"))
            .firstMatch
        return match.exists ? match : nil
    }

    private func printFocus(_ label: String) {
        if let focused = focusedElement() {
            print("FOCUS[\(label)] type=\(focused.elementType.rawValue) label=\(focused.label)")
        } else {
            print("FOCUS[\(label)] <none>")
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
