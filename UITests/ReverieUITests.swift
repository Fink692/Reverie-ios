import XCTest

final class ReverieUITests: XCTestCase {
    func testDashboardEventAndPersistence() {
        let app = XCUIApplication()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Studio"].tap()
        let addEvent = app.buttons["Add event to dashboard"]
        for _ in 0..<4 { if addEvent.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(addEvent.waitForExistence(timeout: 3))
        addEvent.tap()
        XCTAssertTrue(app.alerts["Ready"].waitForExistence(timeout: 3))
        app.alerts["Ready"].buttons["OK"].tap()
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["New order"].firstMatch.waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Activity after order"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["New order"].firstMatch.waitForExistence(timeout: 3))
    }
    func testDashboardEditingAndSceneSwitching() {
        let app = XCUIApplication()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        app.buttons["Edit dashboard"].tap()
        XCTAssertTrue(app.navigationBars["Edit scene"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Northstar"].tap()
        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.staticTexts["Available balance"].waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Banking dashboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Studio Supply"].tap()
    }
}
