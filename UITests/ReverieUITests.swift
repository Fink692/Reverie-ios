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
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            let app = XCUIApplication()
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "Application accessibility tree after failed control wait"
            tree.lifetime = .keepAlways
            add(tree)
            captureScreen("Failed control wait", in: app)
        }
        XCTAssertEqual(result, .completed,
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

    private func openStudioScene(named name: String, in app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        let scene = app.buttons[name]
        scrollTo(scene, in: app, upwards: false)
        scene.tap()
        app.tabBars.buttons["Dashboard"].tap()
        let open = app.buttons["open-scene"]
        scrollTo(open, in: app)
        open.tap()
    }

    private func closePortfolioScene(in app: XCUIApplication) {
        let menu = app.buttons["portfolio-menu"]
        waitForHittable(menu)
        menu.tap()
        let close = app.buttons["close-scene"]
        waitForHittable(close)
        close.tap()
    }

    private func closeWalletScene(in app: XCUIApplication) {
        let menu = app.buttons["wallet-profile-menu"]
        waitForHittable(menu)
        menu.tap()
        let close = app.buttons["Close scene"]
        waitForHittable(close)
        close.tap()
    }

    private func openWalletPage(_ identifier: String, in app: XCUIApplication) {
        let page = app.buttons[identifier]
        if page.isHittable {
            page.tap()
            return
        }
        let menu = app.buttons["wallet-profile-menu"]
        waitForHittable(menu)
        menu.tap()
        let actions = app.sheets.firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        let action = actions.buttons.matching(identifier: identifier).firstMatch
        waitForHittable(action)
        action.tap()
    }

    private func captureScreen(_ name: String, in app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
        cleanPlayback.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "1"), object: cleanPlayback
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        XCTAssertEqual(cleanPlayback.value as? String, "1")
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

    func testHSBCBrandResetRestoresItsBankThemeAndCurrencyOnRelaunch() {
        let app = makeApp(brand: "hsbc")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let brand = app.buttons["bank-brand-exit"]
        waitForHittable(brand)
        XCTAssertTrue(brand.label.localizedCaseInsensitiveContains("HSBC"))
        closeCleanBankScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["New scene"].tap()
        XCTAssertTrue(app.navigationBars["Edit scene"].waitForExistence(timeout: 3))
        replaceText(in: app.textFields["Scene name"], with: "Reset sentinel")
        app.navigationBars["Edit scene"].buttons["Save"].tap()
        let sentinel = app.buttons["Reset sentinel"]
        waitForHittable(sentinel)
        let reset = app.buttons["Reset all scenes"]
        scrollTo(reset, in: app)
        reset.tap()
        let confirm = app.buttons["Reset everything"]
        waitForHittable(confirm)
        confirm.tap()
        let resetFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let reset = object as? XCUIElement else { return false }
                return reset.exists && reset.isEnabled
            }, object: reset
        )
        XCTAssertEqual(XCTWaiter.wait(for: [resetFinished], timeout: 10), .completed)
        scrollTo(app.buttons["Studio Supply"], in: app, upwards: false)
        app.swipeDown()
        waitForHittable(app.buttons["New scene"])
        XCTAssertTrue(app.buttons["Northstar"].isHittable)
        let sentinelRemoved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: sentinel
        )
        XCTAssertEqual(XCTWaiter.wait(for: [sentinelRemoved], timeout: 5), .completed)
        app.terminate()
        app.launch()
        waitForHittable(brand)
        XCTAssertTrue(brand.label.localizedCaseInsensitiveContains("HSBC"))
        XCTAssertFalse(welcome.exists)
        let balance = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "£84,250.75")
        )
        XCTAssertTrue(balance.allElementsBoundByIndex.contains { $0.isHittable }, "HSBC must reopen the reset account in GBP")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "HSBC brand after reset and relaunch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        closeCleanBankScene(in: app)
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
        waitForHittable(openScene)
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

        let checking = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "TOTAL CHECKING")).firstMatch
        scrollTo(checking, in: app)
        checking.tap()
        let accountNavigation = app.navigationBars["Account details"]
        XCTAssertTrue(accountNavigation.waitForExistence(timeout: 5))
        let back = accountNavigation.buttons.element(boundBy: 0)
        waitForHittable(back)
        back.tap()
        waitForHittable(bankPicker)

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
            if !balanceElements.allElementsBoundByIndex.contains(where: { $0.isHittable }) {
                scrollTo(balanceElements.firstMatch, in: app)
            }
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
    func testReferencedBankPaymentReviewCommitAndRelaunch() {
        for brand in ["chase", "bankOfAmerica"] {
            testSessionID = UUID().uuidString
            let app = makeApp(brand: brand)
            app.launch()
            let welcome = app.buttons["Enter your studio"]
            XCTAssertTrue(welcome.waitForExistence(timeout: 5))
            welcome.tap()
            waitForHittable(app.buttons["bank-brand-exit"])
            let initialBalance = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", "$84,250.75")
            )
            XCTAssertTrue(initialBalance.allElementsBoundByIndex.contains { $0.isHittable })
            let pay = app.buttons["bank-tab-payments"]
            waitForHittable(pay)
            pay.tap()

            let recipient = app.textFields["bank.payment.recipient"]
            replaceText(in: recipient, with: "Jordan Lee")
            let amount = app.textFields["bank.payment.amount"]
            replaceText(in: amount, with: "100000")
            let keyboardDone = app.buttons["bank.payment.keyboard.done"]
            waitForHittable(keyboardDone)
            keyboardDone.tap()
            let review = app.buttons["bank.payment.review"]
            scrollTo(review, in: app)
            XCTAssertFalse(review.isEnabled, "An overdraft must not reach payment review")

            scrollTo(amount, in: app, upwards: false)
            replaceText(in: amount, with: "36.25")
            let memo = app.textFields["bank.payment.reference"]
            scrollTo(memo, in: app)
            replaceText(in: memo, with: "Invoice 241")
            waitForHittable(keyboardDone)
            keyboardDone.tap()
            scrollTo(review, in: app)
            review.tap()
            let confirm = app.buttons["bank.payment.confirm"]
            waitForHittable(confirm)
            XCTAssertTrue(app.staticTexts["$36.25"].exists)
            captureScreen("\(brand) payment review", in: app)

            let edit = brand == "chase" ? app.buttons["Edit payment"] : app.buttons["bank.payment.edit"]
            scrollTo(edit, in: app, upwards: false)
            edit.tap()
            XCTAssertTrue(initialBalance.allElementsBoundByIndex.contains { $0.isHittable }, "Review must leave the balance unchanged")
            scrollTo(review, in: app)
            review.tap()
            waitForHittable(confirm)
            confirm.tap()
            XCTAssertTrue(app.staticTexts["bank.payment.receipt"].waitForExistence(timeout: 5))
            captureScreen("\(brand) payment receipt", in: app)
            let done = app.buttons["bank.payment.done"]
            waitForHittable(done)
            done.tap()
            waitForHittable(app.buttons["bank-brand-exit"])
            let paidBalance = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", "$84,214.50")
            )
            XCTAssertTrue(paidBalance.allElementsBoundByIndex.contains { $0.isHittable })
            app.terminate()
            app.launch()
            waitForHittable(app.buttons["bank-brand-exit"])
            XCTAssertTrue(paidBalance.allElementsBoundByIndex.contains { $0.isHittable }, "Confirmed payment must survive relaunch")
            closeCleanBankScene(in: app)
            app.tabBars.buttons["Activity"].tap()
            let savedPayment = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", "Invoice 241")
            )
            XCTAssertTrue(savedPayment.allElementsBoundByIndex.contains { $0.isHittable })
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Invoice 241")).count, 1,
                           "Review and relaunch must not duplicate the payment")
            app.terminate()
        }
    }

    func testEditableShopifyCuePersistsAndQueuesItsCustomizedPayload() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        app.tabBars.buttons["Studio"].tap()
        let library = app.buttons["template-library"]
        scrollTo(library, in: app)
        library.tap()
        let template = app.buttons["builtin-template-shopifyOrder"]
        waitForHittable(template)
        template.tap()
        let amount = app.textFields["Amount in USD"]
        scrollTo(amount, in: app, upwards: false)
        replaceText(in: amount, with: "179.25")
        let keyboardDone = app.toolbars.buttons["Done"].firstMatch
        if keyboardDone.exists { keyboardDone.tap() }
        let title = app.textFields["custom-title"]
        scrollTo(title, in: app)
        replaceText(in: title, with: "Checkout completed")
        if keyboardDone.exists { keyboardDone.tap() }
        let customer = app.textFields["customer"]
        scrollTo(customer, in: app)
        replaceText(in: customer, with: "Morgan Hale")
        if keyboardDone.exists { keyboardDone.tap() }
        let items = app.steppers["item-count"]
        scrollTo(items, in: app)
        items.buttons["item-count-Increment"].tap()
        XCTAssertTrue(items.label.contains("3 items"))
        let number = app.textFields["order-number"]
        scrollTo(number, in: app)
        replaceText(in: number, with: "2088")
        if keyboardDone.exists { keyboardDone.tap() }
        let notificationCount = app.steppers["notification-count"]
        scrollTo(notificationCount, in: app)
        XCTAssertTrue(notificationCount.label.contains("1 notification"))
        let delay = app.buttons["notification-delay"]
        scrollTo(delay, in: app)
        delay.tap()
        app.buttons["5 minutes"].tap()
        let interval = app.buttons["repeat-interval"]
        scrollTo(interval, in: app)
        waitForHittable(interval)
        interval.tap()
        app.buttons["30 seconds"].tap()
        let saveCurrent = app.buttons["save-current-cue"]
        scrollTo(saveCurrent, in: app)
        saveCurrent.tap()
        replaceText(in: app.textFields["cue-name"], with: "Weekend checkout")
        app.buttons["save-cue"].tap()
        XCTAssertTrue(app.navigationBars["Studio"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Studio"].tap()
        let saved = app.buttons["saved-cues"]
        scrollTo(saved, in: app)
        saved.tap()
        let cue = app.buttons["Weekend checkout"]
        waitForHittable(cue)
        cue.tap()
        scrollTo(amount, in: app, upwards: false)
        XCTAssertEqual(amount.value as? String, "179.25")
        scrollTo(title, in: app)
        XCTAssertEqual(title.value as? String, "Checkout completed")
        scrollTo(customer, in: app)
        XCTAssertEqual(customer.value as? String, "Morgan Hale")
        scrollTo(items, in: app)
        XCTAssertTrue(items.label.contains("3 items"))
        scrollTo(number, in: app)
        XCTAssertEqual(number.value as? String, "2088")
        scrollTo(delay, in: app)
        XCTAssertTrue(delay.label.contains("5 minutes"))
        XCTAssertTrue(interval.label.contains("30 seconds"))
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }
        let queueCue = app.buttons["Cue notifications"]
        scrollTo(queueCue, in: app)
        queueCue.tap()
        allowNotificationsIfRequested(in: app)
        XCTAssertTrue(app.alerts["Ready"].waitForExistence(timeout: 10))
        app.alerts["Ready"].buttons["OK"].tap()
        let queue = app.buttons["view-queued-alerts"]
        scrollTo(queue, in: app)
        queue.tap()
        XCTAssertTrue(app.navigationBars["Queued alerts"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Checkout completed"].waitForExistence(timeout: 3))
        let body = "[Studio Supply] You have a new order for 3 items totaling $179.25. From Morgan Hale."
        XCTAssertTrue(app.staticTexts[body].waitForExistence(timeout: 3))
        captureScreen("Customized Shopify cue in system notification queue", in: app)
        let cancel = app.buttons["Cancel Checkout completed"]
        waitForHittable(cancel)
        cancel.tap()
        XCTAssertTrue(app.staticTexts["Your queue is clear"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    func testInvestingWalletAndPredictionThemesRenderSevenHomeScreens() {
        let app = makeApp()
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        openStudioScene(named: "My investments", in: app)
        let portfolioHome = app.buttons["portfolio-tab-home"]
        waitForHittable(portfolioHome)
        captureScreen("Investing playback Robinhood", in: app)
        for name in ["Wealthsimple", "Coinbase"] {
            app.buttons["portfolio-menu"].tap()
            let picker = app.buttons["portfolio-theme-picker"]
            waitForHittable(picker)
            picker.tap()
            let platform = app.buttons[name]
            waitForHittable(platform)
            platform.tap()
            waitForHittable(portfolioHome)
            app.buttons["portfolio-menu"].tap()
            let platformNavigation = app.navigationBars[name]
            XCTAssertTrue(platformNavigation.waitForExistence(timeout: 3))
            platformNavigation.buttons["Done"].tap()
            waitForHittable(portfolioHome)
            let balance = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "$"))
            XCTAssertTrue(balance.allElementsBoundByIndex.contains { $0.isHittable }, "\(name) must show a monetary balance")
            captureScreen("Investing playback \(name)", in: app)
        }
        closePortfolioScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))

        openStudioScene(named: "Wallet 1", in: app)
        let assets = app.buttons["wallet-tab-assets"]
        waitForHittable(assets)
        XCTAssertTrue(app.staticTexts["wallet-total"].isHittable)
        captureScreen("Wallet playback MetaMask", in: app)
        for name in ["Phantom", "Trust Wallet"] {
            app.buttons["wallet-profile-menu"].tap()
            let edit = app.buttons["Edit wallet"]
            waitForHittable(edit)
            edit.tap()
            let picker = app.descendants(matching: .any).matching(identifier: "wallet-theme-picker").firstMatch
            waitForHittable(picker)
            picker.tap()
            let theme = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
            waitForHittable(theme)
            theme.tap()
            let save = app.navigationBars["Wallet settings"].buttons["Save"]
            waitForHittable(save)
            save.tap()
            waitForHittable(assets)
            openWalletPage("wallet-tab-settings", in: app)
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
            assets.tap()
            XCTAssertTrue(app.staticTexts["wallet-total"].isHittable)
            captureScreen("Wallet playback \(name)", in: app)
        }
        closeWalletScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))

        openStudioScene(named: "My predictions", in: app)
        waitForHittable(app.buttons["prediction-tab-home"])
        let market = app.buttons["market-5A110000-0000-4000-8000-000000000023"]
        XCTAssertTrue(market.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["prediction-cash"].label.contains("$2,500.00"))
        captureScreen("Prediction playback Polymarket", in: app)
        app.buttons["prediction-profile-menu"].tap()
        app.buttons["Close scene"].tap()
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
    }

    func testTrustWalletSearchAndCollectibleNavigationPreserveBalances() {
        let app = makeApp(brand: "trustWallet")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        waitForHittable(app.buttons["wallet-tab-assets"])
        let originalBalance = app.staticTexts["wallet-total"].label
        let usdCoin = app.buttons["wallet-asset-usdc"]
        scrollTo(usdCoin, in: app)
        let search = app.textFields["wallet-home-search"]
        scrollTo(search, in: app, upwards: false)
        search.tap()
        search.typeText("USDC")
        let submit = app.keyboards.buttons["Search"]
        waitForHittable(submit)
        submit.tap()
        let ethereum = app.buttons["wallet-asset-eth"]
        scrollTo(usdCoin, in: app)
        XCTAssertFalse(ethereum.exists)
        captureScreen("Trust Wallet filtered assets", in: app)

        let clear = app.buttons["wallet-clear-search"]
        scrollTo(clear, in: app, upwards: false)
        clear.tap()
        let collectibles = app.buttons["wallet-section-nfts"]
        scrollTo(collectibles, in: app)
        collectibles.tap()
        let collectible = app.buttons["wallet-nft-sunset"]
        scrollTo(collectible, in: app)
        captureScreen("Trust Wallet collectible home", in: app)
        collectible.tap()
        let detail = app.descendants(matching: .any).matching(identifier: "wallet-nft-detail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        let done = app.navigationBars.buttons["Done"]
        waitForHittable(done)
        done.tap()
        let crypto = app.buttons["wallet-section-crypto"]
        scrollTo(crypto, in: app, upwards: false)
        crypto.tap()
        scrollTo(ethereum, in: app)
        scrollTo(app.staticTexts["wallet-total"], in: app, upwards: false)
        XCTAssertEqual(app.staticTexts["wallet-total"].label, originalBalance)
        closeWalletScene(in: app)
        XCTAssertTrue(app.navigationBars["Reverie"].waitForExistence(timeout: 5))
    }

    func testRobinhoodPurchaseUpdatesCashAndActivityAfterRelaunch() {
        let app = makeApp(brand: "robinhood")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let assets = app.buttons["portfolio-tab-assets"]
        waitForHittable(assets)
        assets.tap()
        let apple = app.buttons["portfolio-asset-AAPL"]
        waitForHittable(apple)
        apple.tap()
        let buy = app.buttons["portfolio-buy"]
        waitForHittable(buy)
        buy.tap()
        XCTAssertTrue(app.textFields["portfolio-trade-amount"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["portfolio-trade-amount"].value as? String, "100")
        let review = app.buttons["portfolio-trade-review"]
        waitForHittable(review)
        XCTAssertTrue(review.isEnabled)
        review.tap()
        let confirm = app.buttons["portfolio-trade-confirm"]
        waitForHittable(confirm)
        confirm.tap()
        let done = app.buttons["portfolio-trade-done"]
        waitForHittable(done)
        captureScreen("Robinhood purchase receipt", in: app)
        done.tap()
        let back = app.navigationBars["AAPL"].buttons.element(boundBy: 0)
        waitForHittable(back)
        back.tap()
        app.buttons["portfolio-tab-home"].tap()
        let cash = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "$12,400.00"))
        XCTAssertTrue(cash.allElementsBoundByIndex.contains { $0.isHittable })
        app.buttons["portfolio-tab-activity"].tap()
        XCTAssertTrue(app.staticTexts["AAPL buy"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        waitForHittable(app.buttons["portfolio-tab-activity"])
        app.buttons["portfolio-tab-activity"].tap()
        XCTAssertTrue(app.staticTexts["AAPL buy"].waitForExistence(timeout: 3))
        XCTAssertFalse(welcome.exists)
        closePortfolioScene(in: app)
    }

    func testMetaMaskSendUpdatesTokenQuantityAndPersistsTransferHistory() {
        let app = makeApp(brand: "metamask")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let send = app.buttons["wallet-send"]
        waitForHittable(send)
        send.tap()
        replaceText(in: app.textFields["wallet-recipient"], with: "0x0000000000000000000000000000000000000011")
        replaceText(in: app.textFields["wallet-transfer-amount"], with: "0.25")
        let keyboardDone = app.toolbars.buttons["Done"].firstMatch
        if keyboardDone.exists { keyboardDone.tap() }
        let review = app.buttons["wallet-review-transfer"]
        scrollTo(review, in: app)
        XCTAssertTrue(review.isEnabled)
        review.tap()
        let confirm = app.buttons["wallet-confirm-transfer"]
        waitForHittable(confirm)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["wallet-transfer-complete"].waitForExistence(timeout: 5))
        captureScreen("MetaMask send receipt", in: app)
        app.navigationBars["Complete"].buttons["Done"].tap()
        let eth = app.buttons["wallet-asset-eth"]
        scrollTo(eth, in: app)
        XCTAssertTrue(eth.label.contains("4 ETH"))
        openWalletPage("wallet-tab-activity", in: app)
        XCTAssertTrue(app.staticTexts["Sent ETH"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        waitForHittable(app.buttons["wallet-tab-assets"])
        scrollTo(eth, in: app)
        XCTAssertTrue(eth.label.contains("4 ETH"))
        openWalletPage("wallet-tab-activity", in: app)
        XCTAssertTrue(app.staticTexts["Sent ETH"].waitForExistence(timeout: 3))
        XCTAssertFalse(welcome.exists)
        closeWalletScene(in: app)
    }

    func testPolymarketNoPurchasePersistsNewOutcomeAndTradeHistory() {
        let app = makeApp(brand: "polymarket")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let searchTab = app.buttons["prediction-tab-search"]
        waitForHittable(searchTab)
        searchTab.tap()
        let search = app.textFields["prediction-search"]
        replaceText(in: search, with: "Bitcoin")
        let keyboardDone = app.buttons["prediction-search-done"]
        waitForHittable(keyboardDone)
        keyboardDone.tap()
        let buyNo = app.buttons["prediction-no-5A110000-0000-4000-8000-000000000021"]
        scrollTo(buyNo, in: app)
        waitForHittable(buyNo)
        buyNo.tap()
        XCTAssertTrue(app.textFields["prediction-shares"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["prediction-shares"].value as? String, "100")
        let review = app.buttons["prediction-review"]
        scrollTo(review, in: app)
        XCTAssertTrue(review.isEnabled)
        review.tap()
        XCTAssertTrue(app.staticTexts["Cash after trade, $2,464.00"].waitForExistence(timeout: 3))
        let confirm = app.buttons["prediction-confirm"]
        waitForHittable(confirm)
        confirm.tap()
        let done = app.buttons["prediction-trade-done"]
        waitForHittable(done)
        captureScreen("Polymarket No purchase receipt", in: app)
        done.tap()
        app.buttons["prediction-tab-portfolio"].tap()
        XCTAssertTrue(app.staticTexts["No · 100 shares"].waitForExistence(timeout: 3))
        app.buttons["prediction-tab-activity"].tap()
        let trade = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Bought 100 No shares")).firstMatch
        XCTAssertTrue(trade.waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        waitForHittable(app.buttons["prediction-tab-portfolio"])
        app.buttons["prediction-tab-portfolio"].tap()
        XCTAssertTrue(app.staticTexts["No · 100 shares"].waitForExistence(timeout: 3))
        app.buttons["prediction-tab-activity"].tap()
        XCTAssertTrue(trade.waitForExistence(timeout: 3))
        XCTAssertFalse(welcome.exists)
        app.buttons["prediction-profile-menu"].tap()
        app.buttons["Close scene"].tap()
    }

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


extension ReverieUITests {
    func testPolymarketComboReviewPurchaseAndRelaunch() {
        let app = makeApp(brand: "polymarket")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let launcher = app.buttons["prediction-build-combo"]
        scrollTo(launcher, in: app)
        launcher.tap()
        let buy = app.buttons["prediction-combo-review"]
        waitForHittable(buy)
        XCTAssertEqual(app.textFields["prediction-combo-cost"].value as? String, "5.00")
        captureScreen("Polymarket referenced combo ticket", in: app)
        buy.tap()
        XCTAssertTrue(app.staticTexts["Review your combo"].waitForExistence(timeout: 3))
        let edit = app.buttons["prediction-combo-edit"]
        waitForHittable(edit)
        edit.tap()
        waitForHittable(buy)
        buy.tap()
        let confirm = app.buttons["prediction-combo-confirm"]
        waitForHittable(confirm)
        confirm.tap()
        let done = app.buttons["prediction-combo-done"]
        waitForHittable(done)
        XCTAssertFalse(confirm.exists)
        captureScreen("Polymarket combo purchase receipt", in: app)
        done.tap()
        app.buttons["prediction-tab-home"].tap()
        XCTAssertTrue(app.buttons["prediction-cash"].label.contains("$2,495.00"))
        app.buttons["prediction-tab-portfolio"].tap()
        let combos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "prediction-combo-position-"))
        XCTAssertEqual(combos.count, 1)
        app.terminate()
        app.launch()
        waitForHittable(app.buttons["prediction-tab-home"])
        XCTAssertTrue(app.buttons["prediction-cash"].label.contains("$2,495.00"))
        app.buttons["prediction-tab-portfolio"].tap()
        XCTAssertEqual(combos.count, 1)
        app.buttons["prediction-tab-activity"].tap()
        let trades = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "prediction-combo-trade-"))
        XCTAssertTrue(trades.firstMatch.waitForExistence(timeout: 3))
    }

    func testWealthsimpleVisaAndSecuritySettingsPersist() {
        let app = makeApp(brand: "wealthsimple")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let menu = app.buttons["portfolio-menu"]
        waitForHittable(menu)
        menu.tap()
        app.buttons["portfolio-account-visa"].tap()
        let autopay = app.buttons["portfolio-visa-autopay"]
        scrollTo(autopay, in: app)
        captureScreen("Wealthsimple referenced Visa overview", in: app)
        XCTAssertEqual(autopay.value as? String, "Off")
        autopay.tap()
        XCTAssertEqual(autopay.value as? String, "On")
        let manage = app.buttons["portfolio-visa-manage"]
        scrollTo(manage, in: app, upwards: false)
        manage.tap()
        let freeze = app.switches["portfolio-visa-freeze"]
        waitForHittable(freeze)
        freeze.tap()
        XCTAssertEqual(freeze.value as? String, "1")
        app.navigationBars.buttons["Done"].tap()
        menu.tap()
        app.buttons["portfolio-account-security"].tap()
        let security = app.switches["portfolio-security-two-step"]
        scrollTo(security, in: app)
        security.tap()
        XCTAssertEqual(security.value as? String, "1")
        captureScreen("Wealthsimple referenced security", in: app)
        app.terminate()
        app.launch()
        waitForHittable(menu)
        menu.tap()
        app.buttons["portfolio-account-security"].tap()
        scrollTo(security, in: app)
        XCTAssertEqual(security.value as? String, "1")
        menu.tap()
        app.buttons["portfolio-account-visa"].tap()
        scrollTo(autopay, in: app)
        XCTAssertEqual(autopay.value as? String, "On")
        scrollTo(manage, in: app, upwards: false)
        manage.tap()
        waitForHittable(freeze)
        XCTAssertEqual(freeze.value as? String, "1")
    }
}


extension ReverieUITests {
    func testShopifyCatalogOrderKeepsItemsAndFulfillmentAfterRelaunch() {
        let app = makeApp(brand: "commerce")
        app.launch()
        let welcome = app.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let orders = app.buttons["commerce-tab-orders"]
        waitForHittable(orders)
        orders.tap()
        let create = app.buttons["commerce-add-order"]
        waitForHittable(create)
        create.tap()
        replaceText(in: app.textFields["commerce-order-customer"], with: "Casey Rowan")
        let keyboardDone = app.buttons["Done"]
        if keyboardDone.isHittable { keyboardDone.tap() }
        let catalog = app.switches["commerce-order-use-catalog"]
        scrollTo(catalog, in: app)
        catalog.tap()
        let tote = app.steppers["commerce-order-quantity-ad9a767d-602e-4f05-b146-419308632901"]
        scrollTo(tote, in: app)
        XCTAssertTrue(tote.waitForExistence(timeout: 3))
        tote.buttons["Increment"].tap()
        tote.buttons["Increment"].tap()
        let save = app.buttons["commerce-order-save"]
        waitForHittable(save)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let order = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Casey Rowan")).firstMatch
        scrollTo(order, in: app, upwards: false)
        order.tap()
        let item = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@ AND label CONTAINS %@",
            "Everyday tote", "$39.00", "× 2"
        )).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["$78.00"].firstMatch.exists)
        captureScreen("Shopify referenced itemized order", in: app)
        let fulfill = app.buttons["fulfill-order"]
        scrollTo(fulfill, in: app)
        fulfill.tap()
        app.terminate()
        app.launch()
        waitForHittable(orders)
        orders.tap()
        scrollTo(order, in: app, upwards: false)
        order.tap()
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Fulfilled (2)"].exists)
    }
}

extension ReverieUITests {
    func testCoinbaseAndPolymarketExpandedReferenceRoutes() {
        let coinbase = makeApp(brand: "coinbase")
        coinbase.launch()
        let welcome = coinbase.buttons["Enter your studio"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        welcome.tap()
        let menu = coinbase.buttons["portfolio-menu"]
        waitForHittable(menu)
        menu.tap()
        let advanced = coinbase.buttons["portfolio-advanced"]
        waitForHittable(advanced)
        advanced.tap()
        let chartMode = coinbase.buttons["coinbase-advanced-chart-mode"]
        waitForHittable(chartMode)
        XCTAssertEqual(chartMode.value as? String, "Candle")
        XCTAssertTrue(coinbase.staticTexts["BTC-USD"].exists)
        XCTAssertTrue(coinbase.buttons["coinbase-advanced-buy"].isEnabled)
        captureScreen("coinbase-7 Advanced BTC-USD reference", in: coinbase)
        chartMode.tap()
        let line = coinbase.buttons["coinbase-chart-mode-line"]
        waitForHittable(line)
        line.tap()
        XCTAssertEqual(chartMode.value as? String, "Line")
        let closeAdvanced = coinbase.buttons["coinbase-advanced-close"]
        scrollTo(closeAdvanced, in: coinbase, upwards: false)
        closeAdvanced.tap()

        waitForHittable(menu)
        menu.tap()
        let rewards = coinbase.buttons["portfolio-rewards"]
        waitForHittable(rewards)
        rewards.tap()
        XCTAssertTrue(coinbase.navigationBars["Rewards"].waitForExistence(timeout: 3))
        XCTAssertTrue(coinbase.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "Earn 5% rewards"
        )).firstMatch.exists)
        captureScreen("coinbase-4 USDC rewards reference", in: coinbase)
        let buyUSDC = coinbase.buttons["portfolio-rewards-buy"]
        scrollTo(buyUSDC, in: coinbase)
        XCTAssertTrue(buyUSDC.isEnabled)
        coinbase.buttons["Close rewards"].tap()

        waitForHittable(menu)
        menu.tap()
        let securityRoute = coinbase.buttons["portfolio-security"]
        waitForHittable(securityRoute)
        securityRoute.tap()
        XCTAssertTrue(coinbase.navigationBars["Security"].waitForExistence(timeout: 3))
        XCTAssertTrue(coinbase.staticTexts["Let's secure your account"].exists)
        captureScreen("coinbase-6 Account security reference", in: coinbase)
        let security = coinbase.buttons["portfolio-security-two-step"]
        scrollTo(security, in: coinbase)
        XCTAssertEqual(security.value as? String, "Disabled")
        security.tap()
        XCTAssertEqual(security.value as? String, "Enabled")
        XCTAssertTrue(coinbase.staticTexts["Your account is secure"].exists)
        coinbase.buttons["Close security"].tap()
        waitForHittable(menu)
        coinbase.terminate()

        testSessionID = UUID().uuidString
        let polymarket = makeApp(brand: "polymarket")
        polymarket.launch()
        let predictionWelcome = polymarket.buttons["Enter your studio"]
        XCTAssertTrue(predictionWelcome.waitForExistence(timeout: 5))
        predictionWelcome.tap()
        let squads = polymarket.buttons["prediction-tab-squads"]
        waitForHittable(squads)
        squads.tap()
        XCTAssertTrue(polymarket.staticTexts["Logan and friends"].waitForExistence(timeout: 3))
        XCTAssertTrue(polymarket.buttons["prediction-squad-invite"].exists)
        captureScreen("polymarket-5 Squads discovery reference", in: polymarket)
        let join = polymarket.buttons["prediction-squad-pro"]
        scrollTo(join, in: polymarket)
        join.tap()
        XCTAssertTrue(polymarket.navigationBars["Logan and friends"].waitForExistence(timeout: 3))
        XCTAssertEqual(polymarket.buttons["prediction-squad-chat-join"].label, "Joined")
        let message = polymarket.descendants(matching: .any).matching(identifier: "prediction-chat-input").firstMatch
        waitForHittable(message)
        replaceText(in: message, with: "Ready for the next point")
        let send = polymarket.buttons["prediction-chat-send"]
        waitForHittable(send)
        send.tap()
        XCTAssertTrue(polymarket.staticTexts["Ready for the next point"].waitForExistence(timeout: 3))
        captureScreen("polymarket-5 Squad match chat reference", in: polymarket)
        polymarket.navigationBars.buttons["Done"].tap()

        let live = polymarket.buttons["prediction-tab-live"]
        waitForHittable(live)
        live.tap()
        let tennis = polymarket.buttons["prediction-league-tennis"]
        for _ in 0..<3 {
            if tennis.isHittable { break }
            polymarket.buttons["prediction-league-nhl"].swipeLeft()
        }
        waitForHittable(tennis)
        tennis.tap()
        let match = polymarket.buttons["market-5A110000-0000-4000-8000-000000000027"]
        scrollTo(match, in: polymarket)
        match.tap()
        XCTAssertTrue(polymarket.navigationBars["Live match"].waitForExistence(timeout: 3))
        XCTAssertTrue(polymarket.staticTexts["Paused"].exists)
        let buyAlcaraz = polymarket.buttons["prediction-live-buy-yes"]
        waitForHittable(buyAlcaraz)
        XCTAssertTrue(buyAlcaraz.label.contains("Carlos Alcaraz"))
        XCTAssertTrue(buyAlcaraz.label.contains("67¢"))
        captureScreen("polymarket-7 Tennis live match reference", in: polymarket)
        let chartLive = polymarket.buttons["prediction-live-chart-live"]
        scrollTo(chartLive, in: polymarket)
        chartLive.tap()
        let probability = polymarket.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@", "Match probability chart"
        )).firstMatch
        XCTAssertTrue((probability.value as? String)?.hasPrefix("Live:") == true)
        let chat = polymarket.buttons["prediction-live-chat"]
        scrollTo(chat, in: polymarket)
        chat.tap()
        let liveMessage = polymarket.descendants(matching: .any).matching(identifier: "prediction-chat-input").firstMatch
        scrollTo(liveMessage, in: polymarket)
        XCTAssertTrue(liveMessage.exists)
        polymarket.navigationBars.buttons["Done"].tap()
        waitForHittable(live)
        polymarket.terminate()
    }
}

extension ReverieUITests {
    func testWalletExpandedReferenceRoutesKeepBalances() {
        for brand in ["metamask", "phantom", "trustWallet"] {
            testSessionID = UUID().uuidString
            let app = makeApp(brand: brand)
            app.launch()
            let welcome = app.buttons["Enter your studio"]
            XCTAssertTrue(welcome.waitForExistence(timeout: 5))
            welcome.tap()
            waitForHittable(app.buttons["wallet-tab-assets"])
            let total = app.staticTexts["wallet-total"]
            let originalBalance = total.label

            switch brand {
            case "metamask":
                let money = app.buttons["wallet-tab-money"]
                waitForHittable(money)
                money.tap()
                let card = app.buttons["wallet-money-card-overview"]
                scrollTo(card, in: app)
                XCTAssertTrue(app.staticTexts["Estimated earnings"].exists)
                captureScreen("metamask-3 Money account reference", in: app)
                card.tap()
                let addFunds = app.buttons["wallet-card-add-funds"]
                waitForHittable(addFunds)
                XCTAssertTrue(app.buttons["wallet-card-change-asset"].exists)
                captureScreen("metamask-9 Card reference", in: app)
                app.navigationBars.buttons["Back"].tap()
                app.buttons["wallet-tab-assets"].tap()
                let send = app.buttons["wallet-send"]
                scrollTo(send, in: app, upwards: false)
                send.tap()
                replaceText(in: app.textFields["wallet-recipient"], with: "0x1111111111111111111111111111111111111111")
                replaceText(in: app.textFields["wallet-transfer-amount"], with: "0.1")
                let keyboardDone = app.buttons["Done"]
                waitForHittable(keyboardDone)
                keyboardDone.tap()
                let review = app.buttons["wallet-review-transfer"]
                scrollTo(review, in: app)
                XCTAssertTrue(review.isEnabled)
                review.tap()
                XCTAssertTrue(app.navigationBars["Transfer request"].waitForExistence(timeout: 3))
                let transfer = app.buttons["wallet-confirm-transfer"]
                waitForHittable(transfer)
                XCTAssertTrue(transfer.isEnabled)
                captureScreen("metamask-7 Transfer request reference", in: app)
                app.buttons["wallet-cancel-transfer"].tap()
                XCTAssertTrue(app.navigationBars["Send"].waitForExistence(timeout: 3))
                app.navigationBars.buttons["Cancel"].tap()

            case "phantom":
                let trade = app.buttons["wallet-tab-trade"]
                waitForHittable(trade)
                trade.tap()
                XCTAssertTrue(app.buttons["wallet-swap-from-asset"].waitForExistence(timeout: 3))
                XCTAssertTrue(app.buttons["wallet-swap-to-asset"].exists)
                captureScreen("phantom-3 Trade reference", in: app)
                let explore = app.buttons["wallet-tab-explore"]
                waitForHittable(explore)
                explore.tap()
                XCTAssertTrue(app.buttons["wallet-explore-filter-tokens"].waitForExistence(timeout: 3))
                XCTAssertTrue(app.staticTexts["Trending Tokens"].exists)
                captureScreen("phantom-4 Explore reference", in: app)

            default:
                let settings = app.buttons["wallet-tab-settings"]
                waitForHittable(settings)
                settings.tap()
                let staking = app.buttons["wallet-staking"]
                scrollTo(staking, in: app)
                staking.tap()
                XCTAssertTrue(app.navigationBars["Earn"].waitForExistence(timeout: 3))
                XCTAssertTrue(app.staticTexts["Native Staking"].exists)
                XCTAssertTrue(app.staticTexts["36.00% APR"].exists)
                captureScreen("trustWallet-6 Native staking reference", in: app)
                app.navigationBars.buttons["Back"].tap()
                let connections = app.buttons["Connections"]
                scrollTo(connections, in: app)
                connections.tap()
                let connect = app.buttons["wallet-connect-app"]
                waitForHittable(connect)
                connect.tap()
                let confirmConnection = app.buttons["wallet-confirm-connection"]
                waitForHittable(confirmConnection)
                XCTAssertTrue(app.staticTexts["pancakeswap.finance"].exists)
                captureScreen("trustWallet-7 Connection request reference", in: app)
                app.buttons["Cancel"].tap()
                XCTAssertTrue(app.navigationBars["Connections"].waitForExistence(timeout: 3))
                app.navigationBars.buttons["Done"].tap()
                let risk = app.buttons["wallet-security-alert"]
                scrollTo(risk, in: app)
                risk.tap()
                let dismissRisk = app.buttons["wallet-dismiss-risk"]
                waitForHittable(dismissRisk)
                XCTAssertTrue(app.staticTexts["Critical Risk Alert"].exists)
                captureScreen("trustWallet-8 Risk alert reference", in: app)
                dismissRisk.tap()
                waitForHittable(settings)
            }

            let home = app.buttons["wallet-tab-assets"]
            waitForHittable(home)
            home.tap()
            scrollTo(total, in: app, upwards: false)
            XCTAssertEqual(total.label, originalBalance)
            app.terminate()
        }
    }
}

extension ReverieUITests {
    func testStarlingSpacesAndMonzoHolidayReferenceRoutes() {
        for brand in ["starling", "monzo"] {
            testSessionID = UUID().uuidString
            let app = makeApp(brand: brand)
            app.launch()
            let welcome = app.buttons["Enter your studio"]
            XCTAssertTrue(welcome.waitForExistence(timeout: 5))
            welcome.tap()
            waitForHittable(app.buttons["bank-brand-exit"])

            if brand == "starling" {
                let spaces = app.buttons["bank-tab-spaces"]
                waitForHittable(spaces)
                spaces.tap()
                let bills = app.buttons["bank.spaces.bills"]
                scrollTo(bills, in: app)
                XCTAssertTrue(app.buttons["bank.spaces.groceries"].exists)
                captureScreen("starling-2 Spaces reference", in: app)
                bills.tap()
                let detail = app.navigationBars["Monthly Bills"]
                XCTAssertTrue(detail.waitForExistence(timeout: 3))
                let manage = app.buttons["Manage Space"]
                waitForHittable(manage)
                XCTAssertTrue(manage.isEnabled)
                captureScreen("starling-4 Monthly Bills space reference", in: app)
                detail.buttons.element(boundBy: 0).tap()
                waitForHittable(spaces)
                app.buttons["bank-tab-home"].tap()
            } else {
                let holiday = app.buttons["bank.savings.holiday"]
                scrollTo(holiday, in: app)
                holiday.tap()
                let savings = app.navigationBars["Savings"]
                XCTAssertTrue(savings.waitForExistence(timeout: 3))
                XCTAssertTrue(app.staticTexts["Holiday Fund"].exists)
                XCTAssertTrue(app.buttons["Withdraw"].isEnabled)
                XCTAssertTrue(app.buttons["Add money"].isEnabled)
                captureScreen("monzo-6 Holiday savings reference", in: app)
                savings.buttons.element(boundBy: 0).tap()
                waitForHittable(holiday)
            }

            waitForHittable(app.buttons["bank-brand-exit"])
            app.terminate()
        }
    }
}
