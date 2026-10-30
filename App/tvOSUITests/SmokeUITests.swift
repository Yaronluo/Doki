import XCTest

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

    private func attach(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
