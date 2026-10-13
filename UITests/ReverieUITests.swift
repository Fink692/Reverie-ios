import XCTest

final class ReverieUITests: XCTestCase {
    private var testSessionID = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        testSessionID = UUID().uuidString
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-session", testSessionID, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        return app
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let existing = field.value as? String ?? ""
        if !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(text)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true) {
        for _ in 0..<8 {
            if element.isHittable { return }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func allowNotificationsIfRequested(in app: XCUIApplication) {
        let systemAllow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if systemAllow.waitForExistence(timeout: 3) {
            systemAllow.tap()
        } else {
            app.tap()
        }
    }

    func testOnboardingStaysDismissedAfterRelaunch() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        XCTAssertFalse(welcome.exists)
    }

    func testNewSceneValidationAndPersistence() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        app.tabBars.buttons["Settings"].tap()
        app.buttons["New scene"].tap()
        XCTAssertTrue(app.navigationBars["Edit scene"].waitForExistence(timeout: 3))
        replaceText(in: app.textFields["Scene name"], with: "After Hours")
        let balance = app.textFields["Available balance in USD"]
        replaceText(in: balance, with: "1000000001")
        let save = app.navigationBars["Edit scene"].buttons["Save"]
        XCTAssertFalse(save.isEnabled)
        replaceText(in: balance, with: "12450.75")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.staticTexts["After Hours"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["After Hours"].waitForExistence(timeout: 5))
        app.buttons["Edit dashboard"].tap()
        XCTAssertTrue(balance.waitForExistence(timeout: 3))
        XCTAssertEqual(balance.value as? String, "12450.75")
        app.buttons["Cancel"].tap()
    }

    func testDashboardEventAndPersistence() {
        let app = makeApp()
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
        let app = makeApp()
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

    func testCommercePlaybackTabsAndReturnToStudio() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        let openScene = app.buttons["open-scene"]
        scrollTo(openScene, in: app)
        openScene.tap()
        let closeScene = app.buttons["close-scene"]
        XCTAssertTrue(closeScene.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["commerce-tab-home"].isHittable)
        let homeScreenshot = XCTAttachment(screenshot: app.screenshot())
        homeScreenshot.name = "Commerce playback home"
        homeScreenshot.lifetime = .keepAlways
        add(homeScreenshot)

        app.buttons["commerce-tab-orders"].tap()
        XCTAssertTrue(app.textFields["Search orders"].waitForExistence(timeout: 3))
        XCTAssertTrue(closeScene.isHittable)
        let ordersScreenshot = XCTAttachment(screenshot: app.screenshot())
        ordersScreenshot.name = "Commerce playback orders"
        ordersScreenshot.lifetime = .keepAlways
        add(ordersScreenshot)

        app.buttons["commerce-tab-products"].tap()
        XCTAssertTrue(app.textFields["Search products"].waitForExistence(timeout: 3))
        XCTAssertTrue(closeScene.isHittable)
        app.buttons["commerce-tab-store"].tap()
        XCTAssertTrue(app.buttons["Store settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(closeScene.isHittable)
        app.buttons["commerce-tab-home"].tap()
        closeScene.tap()
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Studio"].tap()
        XCTAssertTrue(app.navigationBars["Studio"].waitForExistence(timeout: 3))
    }

    func testBankPlaybackThemesAndReturnToDashboard() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Northstar"].tap()
        app.tabBars.buttons["Dashboard"].tap()
        let openScene = app.buttons["open-scene"]
        scrollTo(openScene, in: app)
        openScene.tap()
        let bankPicker = app.buttons["bank-theme-picker"]
        XCTAssertTrue(bankPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(bankPicker.isHittable)
        XCTAssertTrue(bankPicker.label.contains("Chase"))
        let chaseScreenshot = XCTAttachment(screenshot: app.screenshot())
        chaseScreenshot.name = "Bank playback Chase"
        chaseScreenshot.lifetime = .keepAlways
        add(chaseScreenshot)

        for name in ["Monzo", "Revolut"] {
            bankPicker.tap()
            let bank = app.buttons[name]
            XCTAssertTrue(bank.waitForExistence(timeout: 3))
            bank.tap()
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", name), object: bankPicker
            )
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Bank playback \(name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app.buttons["close-scene"].tap()
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Northstar"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        scrollTo(openScene, in: app)
        openScene.tap()
        XCTAssertTrue(bankPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(bankPicker.label.contains("Revolut"))
        app.buttons["close-scene"].tap()
    }
}

extension ReverieUITests {
    func testNotificationSessionCanBeQueuedAndCancelled() {
        let app = makeApp()
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
        allowNotificationsIfRequested(in: app)
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

    func testSavedCueSurvivesRelaunchAndCanCancelItsQueuedAlert() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        app.tabBars.buttons["Studio"].tap()
        let amount = app.textFields["Amount in USD"]
        replaceText(in: amount, with: "289.50")
        app.buttons["Done"].tap()
        let delay = app.buttons["notification-delay"]
        scrollTo(delay, in: app)
        delay.tap()
        app.buttons["5 minutes"].tap()
        let saveCue = app.buttons["save-current-cue"]
        scrollTo(saveCue, in: app)
        saveCue.tap()
        XCTAssertTrue(app.navigationBars["Save cue"].waitForExistence(timeout: 3))
        replaceText(in: app.textFields["cue-name"], with: "Launch drop")
        app.buttons["save-cue"].tap()
        XCTAssertTrue(app.navigationBars["Studio"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Studio"].tap()
        let savedCues = app.buttons["saved-cues"]
        scrollTo(savedCues, in: app)
        savedCues.tap()
        XCTAssertTrue(app.navigationBars["Saved cues"].waitForExistence(timeout: 3))
        app.buttons["Launch drop"].tap()
        scrollTo(amount, in: app, upwards: false)
        XCTAssertEqual(amount.value as? String, "289.5")
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }
        let cue = app.buttons["Cue notifications"]
        scrollTo(cue, in: app)
        cue.tap()
        allowNotificationsIfRequested(in: app)
        XCTAssertTrue(app.alerts["Ready"].waitForExistence(timeout: 10))
        app.alerts["Ready"].buttons["OK"].tap()
        let queue = app.buttons["view-queued-alerts"]
        scrollTo(queue, in: app)
        queue.tap()
        XCTAssertTrue(app.navigationBars["Queued alerts"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["New order"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Cancel New order"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your queue is clear"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }
}
