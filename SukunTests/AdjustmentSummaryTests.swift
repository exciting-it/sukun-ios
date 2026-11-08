import XCTest
@testable import Sukun
@testable import SukunKit

final class AdjustmentSummaryTests: XCTestCase {
    func testSummaryListsNonZeroInPrayerOrderWithRealMinus() {
        XCTAssertNil(AdjustmentSummary.text([:]))
        XCTAssertNil(AdjustmentSummary.text([.isha: 0]))
        XCTAssertEqual(AdjustmentSummary.text([.isha: 5, .fajr: -2]), "Fajr \u{2212}2, Isha +5")
    }

    func testSignedMinutes() {
        XCTAssertEqual(AdjustmentSummary.signed(0), "0")
        XCTAssertEqual(AdjustmentSummary.signed(7), "+7")
        XCTAssertEqual(AdjustmentSummary.signed(-30), "\u{2212}30")
    }
}
