import XCTest

final class ReverieUITests: XCTestCase {
    private var testSessionID = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        testSessionID = UUID().uuidString
    }

    private func makeApp(brand: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-session", testSessionID, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let brand { app.launchArguments += ["-ui-test-brand", brand] }
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

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let element = object as? XCUIElement else { return false }
                return element.exists && element.isHittable
            },
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "The control did not become hittable within \(timeout) seconds.", file: file, line: line)
    }

    private func closeCleanCommerceScene(in app: XCUIApplication) {
        let profile = app.buttons["Store profile and close scene"]
        waitForHittable(profile)
        profile.tap()
        let close = app.buttons["Close scene"]
        waitForHittable(close)
        close.tap()
    }

    private func closeCleanBankScene(in app: XCUIApplication) {
        let brand = app.buttons["bank-brand-exit"]
        waitForHittable(brand)
        brand.press(forDuration: 2.2)
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

    func testCommerceBrandStartsInPlaybackAfterOnboardingAndRelaunch() {
        let app = makeApp(brand: "commerce")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let home = app.buttons["commerce-tab-home"]
        waitForHittable(home)
        XCTAssertFalse(app.buttons["close-scene"].exists)
        closeCleanCommerceScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Northstar"].tap()
        app.terminate()
        app.launch()
        waitForHittable(home)
        XCTAssertFalse(welcome.exists)
        XCTAssertFalse(app.buttons["close-scene"].exists)
        closeCleanCommerceScene(in: app)
    }

    func testBankBrandStartsInPlaybackAfterOnboardingAndRelaunch() {
        let app = makeApp(brand: "chase")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let brand = app.buttons["bank-brand-exit"]
        waitForHittable(brand)
        XCTAssertTrue(brand.label.localizedCaseInsensitiveContains("Chase"))
        XCTAssertFalse(app.buttons["bank-theme-picker"].exists)
        XCTAssertFalse(app.buttons["close-scene"].exists)
        closeCleanBankScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Northstar"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Studio Supply"].tap()
        app.terminate()
        app.launch()
        waitForHittable(brand)
        XCTAssertTrue(brand.label.localizedCaseInsensitiveContains("Chase"))
        XCTAssertFalse(welcome.exists)
        closeCleanBankScene(in: app)
    }

    func testCleanPlaybackHidesChromeAndRetainsCommerceAndBankExitControls() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        app.tabBars.buttons["Settings"].tap()
        let cleanPlayback = app.switches["clean-playback"]
        scrollTo(cleanPlayback, in: app)
        cleanPlayback.tap()
        app.tabBars.buttons["Dashboard"].tap()
        let openScene = app.buttons["open-scene"]
        scrollTo(openScene, in: app)
        openScene.tap()
        waitForHittable(app.buttons["commerce-tab-home"])
        XCTAssertFalse(app.buttons["close-scene"].exists)
        let commerceScreenshot = XCTAttachment(screenshot: app.screenshot())
        commerceScreenshot.name = "Clean commerce playback"
        commerceScreenshot.lifetime = .keepAlways
        add(commerceScreenshot)
        closeCleanCommerceScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        let northstar = app.buttons["Northstar"]
        scrollTo(northstar, in: app, upwards: false)
        northstar.tap()
        app.tabBars.buttons["Dashboard"].tap()
        scrollTo(openScene, in: app)
        openScene.tap()
        waitForHittable(app.buttons["bank-brand-exit"])
        XCTAssertFalse(app.buttons["close-scene"].exists)
        XCTAssertFalse(app.buttons["bank-theme-picker"].exists)
        let bankScreenshot = XCTAttachment(screenshot: app.screenshot())
        bankScreenshot.name = "Clean bank playback Chase"
        bankScreenshot.lifetime = .keepAlways
        add(bankScreenshot)
        closeCleanBankScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Northstar"].waitForExistence(timeout: 3))
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
        waitForHittable(bankPicker)
        XCTAssertTrue(bankPicker.label.contains("Chase"))
        let balanceElements = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "$84,250.75")
        )
        XCTAssertTrue(balanceElements.allElementsBoundByIndex.contains { $0.isHittable }, "Chase must show the selected scene's balance")
        let chaseScreenshot = XCTAttachment(screenshot: app.screenshot())
        chaseScreenshot.name = "Bank playback Chase"
        chaseScreenshot.lifetime = .keepAlways
        add(chaseScreenshot)

        let bankNames = [
            "Bank of America", "Wells Fargo", "Citi", "Capital One", "HSBC", "Barclays",
            "Lloyds Bank", "NatWest", "Monzo", "Starling Bank", "Revolut"
        ]
        for name in bankNames {
            bankPicker.tap()
            let bank = app.buttons[name]
            XCTAssertTrue(bank.waitForExistence(timeout: 3))
            bank.tap()
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", name), object: bankPicker
            )
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
            waitForHittable(bankPicker)
            XCTAssertTrue(balanceElements.allElementsBoundByIndex.contains { $0.isHittable }, "\(name) must show the selected scene's balance")
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
        waitForHittable(bankPicker)
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
