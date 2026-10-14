import XCTest

final class RaftPersonalUITests: XCTestCase {
    private func start() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    private func enter(_ text: String, in app: XCUIApplication) {
        let field = app.textFields["serverAddress"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        if let existing = field.value as? String, existing != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(text)
        app.buttons["connectButton"].tap()
    }

    private func edit(in app: XCUIApplication) {
        app.webViews.buttons["Settings"].tap()
        app.webViews.buttons["服务器设置"].tap()
    }

    func testInvalidAddressShowsInlineError() {
        let app = start()
        enter("javascript:alert(1)", in: app)
        XCTAssertTrue(app.staticTexts["addressError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["connectionMenu"].exists)
    }

    func testProfileIsolationPersistenceAndHTTPRecovery() {
        let app = start()
        enter("http://localhost:8767", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Raft fixture"].waitForExistence(timeout: 15))
        let draft = app.webViews.textFields["Draft"]
        draft.tap()
        draft.typeText("private-draft")
        app.webViews.buttons["Settings"].tap()
        app.webViews.buttons["服务器设置"].tap()
        app.buttons["取消"].tap()
        XCTAssertFalse(app.buttons["connectionMenu"].exists)
        XCTAssertEqual(draft.value as? String, "private-draft", "Opening settings must not rebuild WebView")

        edit(in: app)
        enter("http://127.0.0.1:8767", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Raft fixture"].waitForExistence(timeout: 15))
        XCTAssertNotEqual(app.webViews.textFields["Draft"].value as? String, "private-draft")
        edit(in: app)
        enter("http://localhost:8767", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Raft fixture"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.webViews.textFields["Draft"].value as? String, "private-draft")

        app.terminate()
        app.launchArguments = ["--ui-testing", "--keep-test-data"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Raft fixture"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.webViews.textFields["Draft"].value as? String, "private-draft")
        app.webViews.links["HTTP error"].tap()
        XCTAssertTrue(app.staticTexts["loadError"].waitForExistence(timeout: 8))
        app.buttons["回到首页"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Raft fixture"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.webViews.textFields["Draft"].value as? String, "private-draft")
    }
}
