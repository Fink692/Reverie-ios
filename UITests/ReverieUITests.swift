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

extension ReverieUITests {
    func testNotificationSessionCanBeQueuedAndCancelled() {
        let app = XCUIApplication()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }
        app.tabBars.buttons["Studio"].tap()
        let delayPicker = app.buttons["notification-delay"]
        for _ in 0..<6 { if delayPicker.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(delayPicker.waitForExistence(timeout: 3))
        delayPicker.tap()
        let later = app.buttons["5 minutes"]
        XCTAssertTrue(later.waitForExistence(timeout: 3))
        later.tap()
        let cue = app.buttons["Cue notifications"]
        if !cue.isHittable { app.swipeUp() }
        cue.tap()
        // The interaction gives XCTest's permission interruption handler a chance to run.
        app.tap()
        XCTAssertTrue(app.alerts["Ready"].waitForExistence(timeout: 10))
        app.alerts["Ready"].buttons["OK"].tap()
        let cancel = app.buttons["Cancel 1 queued alerts"]
        for _ in 0..<3 { if cancel.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()
        let disappears = NSPredicate(format: "exists == false")
        expectation(for: disappears, evaluatedWith: cancel)
        waitForExpectations(timeout: 5)
    }
}
