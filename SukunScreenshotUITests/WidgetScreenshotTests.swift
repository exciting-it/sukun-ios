import XCTest

/// Places real Sukun widgets through SpringBoard (simulator) and saves screenshots for the App Store.
/// Run via scripts/widget-screenshots.sh, which seeds the city and sets the language and status bar.
final class WidgetScreenshotTests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    /// SpringBoard's own labels in the languages we shoot (en, de, ar).
    private let editLabels = ["Edit", "Bearbeiten", "تعديل"]
    private let doneLabels = ["Done", "Fertig", "تم"]
    private let addWidgetLabels = ["Add Widget", "Widget hinzufügen", "إضافة أداة"]
    private let closeLabels = ["close", "Close", "schließen", "Schließen", "إغلاق"]
    /// The app's display name follows the device language (InfoPlist.xcstrings).
    private var appName: String {
        let language = ProcessInfo.processInfo.environment["SUKUN_LANG"] ?? Locale.preferredLanguages.first ?? "en"
        return language.hasPrefix("ar") ? "سكون" : "Sukun"
    }

    private func button(_ labels: [String]) -> XCUIElement {
        springboard.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    }

    private func buttonContaining(_ labels: [String]) -> XCUIElement {
        let predicates = labels.map { NSPredicate(format: "label CONTAINS %@", $0) }
        return springboard.buttons.matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates)).firstMatch
    }

    /// Gallery pages, in WidgetBundle order.
    private enum Page: Int { case current = 0, today, overview, qibla }

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        if testRun?.hasSucceeded == false { print("FAIL-DUMP-START\n\(springboard.debugDescription)\nFAIL-DUMP-END") }
    }

    func testHomeScreen() throws {
        seedApp()
        XCUIDevice.shared.press(.home)
        sleep(1)
        goToFirstHomePage()
        enterEditMode()
        // New widgets go in at the top, so add the bottom one first.
        addWidget(.overview)
        enterEditMode()
        addWidget(.qibla)
        enterEditMode()
        addWidget(.current)
        tapDone()
        sleep(3) // let the widgets render
        save("home")
    }

    func testLockScreen() throws {
        seedApp()
        lock()
        sleep(2)
        XCUIDevice.shared.press(.home) // wake: Lock Screen
        sleep(2)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.5)
        let customize = springboard.buttons["posterboard-customize-button"]
        XCTAssertTrue(customize.waitForExistence(timeout: 5))
        customize.tap()
        XCTAssertTrue(springboard.buttons["editing-done"].waitForExistence(timeout: 10))
        sleep(2)

        // Below the clock: rectangular + circular.
        springboard.buttons["grouped-widgets-reticle-view"].firstMatch.tap()
        openSukunInPicker()
        tapWidget(wide: true)  // rectangular
        tapWidget(wide: false) // circular
        closePicker()

        // Above the clock: inline.
        springboard.buttons["inline-widget-reticle-view"].firstMatch.tap()
        sleep(3)
        // The inline picker lists widgets directly: "Sukun, Current Prayer, Top Widget".
        let inline = springboard.cells.matching(NSPredicate(format: "label BEGINSWITH %@", appName)).firstMatch
        for _ in 0..<10 where !(inline.exists && inline.isHittable) {
            springboard.cells.element(boundBy: 0).swipeUp()
            sleep(1)
        }
        XCTAssertTrue(inline.isHittable)
        inline.tap()
        sleep(2)
        // This sheet has no close button: drag its grabber down.
        for _ in 0..<3 where !springboard.buttons["editing-done"].isHittable {
            let grabber = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.405))
            grabber.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99)))
            sleep(2)
        }

        springboard.buttons["editing-done"].tap()
        sleep(3)
        // Back on the Lock Screen (iOS may ask to also set the Home Screen; keep it as is).
        let keep = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Done' OR label CONTAINS[c] 'Set as Wallpaper Pair'")).firstMatch
        if keep.exists { keep.tap(); sleep(2) }
        XCUIDevice.shared.press(.home) // unlock
        sleep(1)
        lock()
        sleep(2)
        XCUIDevice.shared.press(.home) // wake again: clean Lock Screen with the widgets
        sleep(4)
        save("lock")
    }

    private func openSukunInPicker() {
        sleep(2)
        let sukun = springboard.cells[appName].firstMatch
        for _ in 0..<20 where !sukun.isHittable {
            let anyCell = springboard.cells.element(boundBy: 0)
            anyCell.exists ? anyCell.swipeUp() : springboard.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(sukun.isHittable)
        sukun.tap()
        sleep(2)
    }

    /// Lock Screen widget previews, told apart by shape (labels are localized): rectangular is wide, circular square.
    private func tapWidget(wide: Bool) {
        let previews = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", appName))
        XCTAssertTrue(previews.firstMatch.waitForExistence(timeout: 5))
        let widget = previews.allElementsBoundByIndex.first { ($0.frame.width > $0.frame.height * 1.5) == wide }
        XCTAssertNotNil(widget)
        widget?.tap()
        sleep(1)
    }

    /// Dismiss the widget picker sheet: its close button (twice if it first steps back to the app list),
    /// or a tap on the free strip between the widgets and the sheet.
    private func closePicker() {
        for _ in 0..<4 {
            let close = button(closeLabels)
            if close.exists, close.isHittable {
                close.tap()
            } else if springboard.cells[appName].exists {
                springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()
            } else {
                break
            }
            sleep(2)
        }
    }

    private func lock() {
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    }

    // MARK: Steps

    private func seedApp() {
        let app = XCUIApplication()
        app.launchArguments = ProcessInfo.processInfo.environment["SUKUN_APP_ARGS"]?
            .split(separator: " ").map(String.init) ?? ["-SukunScreenshotCity", "berlin"]
        app.launch()
        sleep(3)
    }

    /// The first Home Screen page (Apple's apps; the test runner's icon lands on a later page).
    private func goToFirstHomePage() {
        let indicator = springboard.pageIndicators.firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 5))
        func current() -> Int? {
            let value = (indicator.value as? String) ?? ""
            let numbers = value.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            return numbers.count == 2 ? numbers[0] : nil
        }
        // Right-to-left layouts page the other way: if a swipe went forward, swipe the other way.
        var swipeRight = true
        for _ in 0..<8 {
            guard let page = current(), page > 1 else { return }
            swipeRight ? springboard.swipeRight() : springboard.swipeLeft()
            sleep(1)
            if let after = current(), after > page { swipeRight.toggle() }
        }
    }

    private func enterEditMode() {
        if !button(doneLabels).exists {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.5)
            sleep(1)
        }
        let edit = button(editLabels)
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        sleep(1)
        let add = button(addWidgetLabels)
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        sleep(2)
    }

    private func addWidget(_ page: Page) {
        let search = springboard.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(appName)
        sleep(1)
        springboard.cells[appName].firstMatch.tap()
        sleep(2)
        let preview = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", appName + ",")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        // The gallery's page control (the wide one, not the Home Screen's): tapping its trailing end goes one
        // page on; in right-to-left languages the trailing end is on the left.
        let pages = springboard.pageIndicators.allElementsBoundByIndex.first { $0.frame.width > 300 }
        let pageControl = try? XCTUnwrap(pages)
        let rtl = editLabels.last.map { button([$0]).exists } ?? false
        for _ in 0..<page.rawValue {
            pageControl?.coordinate(withNormalizedOffset: CGVector(dx: rtl ? 0.05 : 0.95, dy: 0.5)).tap()
            sleep(1)
        }
        let add = buttonContaining(addWidgetLabels)
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        sleep(2)
    }

    private func tapDone() {
        let done = button(doneLabels)
        if done.waitForExistence(timeout: 3) { done.tap() }
        sleep(1)
    }

    private func save(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SUKUN_SHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
