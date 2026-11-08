import SwiftUI
import UIKit
import XCTest
@testable import Sukun
@testable import SukunKit

/// Inspects the real UIKit accessibility tree SwiftUI builds for a prayer row, the same tree VoiceOver reads.
@MainActor
final class PrayerRowAccessibilityTests: XCTestCase {
    private let formatter = PrayerTimeFormatter(clockFormat: .twentyFourHour, timeZone: TimeZone(identifier: "Europe/Berlin")!,
                                                locale: Locale(identifier: "en_US"))

    override class func setUp() {
        super.setUp()
        // SwiftUI only builds its accessibility tree while assistive technology is on; switch on automation
        // accessibility the way KIF and AccessibilitySnapshot do.
        if let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
           let symbol = dlsym(handle, "_AXSSetAutomationEnabled") {
            typealias SetEnabled = @convention(c) (Bool) -> Void
            unsafeBitCast(symbol, to: SetEnabled.self)(true)
        }
    }

    private var keepAlive: [UIWindow] = []

    private func elements(for row: some View, wait: TimeInterval = 0.3) -> [NSObject] {
        let host = UIHostingController(rootView: row)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        keepAlive.append(window)
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))
        return collect(host.view)
    }

    private func collect(_ root: UIView) -> [NSObject] {
        var found: [NSObject] = []
        func walk(_ node: NSObject, depth: Int) {
            guard depth < 12 else { return }
            if node.isAccessibilityElement { found.append(node) }
            if let children = node.accessibilityElements as? [NSObject] {
                children.forEach { walk($0, depth: depth + 1) }
            } else if let view = node as? UIView {
                let count = view.accessibilityElementCount()
                if count != NSNotFound, count > 0 {
                    (0..<count).compactMap { view.accessibilityElement(at: $0) as? NSObject }.forEach { walk($0, depth: depth + 1) }
                }
                view.subviews.forEach { walk($0, depth: depth + 1) }
            }
        }
        walk(root, depth: 0)
        return found
    }

    func testRowIsOneElementCarryingTheReminderAction() {
        let slot = PrayerSlot(kind: .isha, date: Date(timeIntervalSince1970: 1_800_000_000))
        let row = PrayerRow(slot: slot, isCurrent: false, isPast: false, formatter: formatter,
                            notificationEnabled: false, onToggleNotification: { _ in })
        let found = elements(for: row)
        XCTAssertEqual(found.count, 1, "the bell must not be a separate element")
        XCTAssertEqual(found.first?.accessibilityCustomActions?.map(\.name), ["Turn notification on"])
    }

    func testDoubleTapOnTheRowTogglesTheReminder() {
        var toggled: [Bool] = []
        let slot = PrayerSlot(kind: .isha, date: Date(timeIntervalSince1970: 1_800_000_000))
        let row = PrayerRow(slot: slot, isCurrent: false, isPast: false, formatter: formatter,
                            notificationEnabled: false, onToggleNotification: { toggled.append($0) })
        let element = elements(for: row).first
        XCTAssertTrue(element?.accessibilityTraits.contains(.toggleButton) ?? false, "read as a switch")
        XCTAssertTrue(element?.accessibilityActivate() ?? false)
        XCTAssertEqual(toggled, [true])
    }

    func testSunriseRowHasNoAction() {
        let slot = PrayerSlot(kind: .sunrise, date: Date(timeIntervalSince1970: 1_800_000_000))
        let row = PrayerRow(slot: slot, isCurrent: false, isPast: false, formatter: formatter,
                            notificationEnabled: false, onToggleNotification: nil)
        let found = elements(for: row)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.accessibilityCustomActions ?? [], [])
        XCTAssertFalse(found.first?.accessibilityTraits.contains(.toggleButton) ?? true)
    }

    func testRowElementsInTodayStayStable() throws {
        let defaults = UserDefaults(suiteName: "sukun.a11y.\(UUID().uuidString)")!
        let model = AppModel(store: SharedStore(defaults: defaults))
        model.useManualLocation(StoredLocation(coordinate: Coordinate(latitude: 52.52, longitude: 13.405), name: "Berlin",
                                               countryCode: "DE", timeZoneIdentifier: "Europe/Berlin", source: .manual))
        let first = elements(for: TodayView().environment(model), wait: 0.5)
        let rowsBefore = first.filter { ($0.accessibilityLabel ?? "").hasPrefix("Isha") }
        RunLoop.main.run(until: Date().addingTimeInterval(2.5))
        let root = try XCTUnwrap(keepAlive.last?.rootViewController?.view)
        let after = collect(root)
        let rowsAfter = after.filter { ($0.accessibilityLabel ?? "").hasPrefix("Isha") }
        XCTAssertEqual(rowsBefore.count, 1)
        XCTAssertTrue(rowsBefore.first === rowsAfter.first, "row element was recreated while focused")
    }
}
