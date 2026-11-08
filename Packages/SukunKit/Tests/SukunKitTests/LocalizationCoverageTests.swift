import Foundation
import XCTest
@testable import SukunKit

/// Every string in every catalog of the app, the widgets and SukunKit has a German and an Arabic value,
/// with the same placeholders as English. Catches new strings that were added in English only.
final class LocalizationCoverageTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private let catalogs = [
        "Sukun/Resources/Localizable.xcstrings",
        "Sukun/Resources/InfoPlist.xcstrings",
        "SukunWidgets/Resources/Localizable.xcstrings",
        "SukunWidgets/Resources/InfoPlist.xcstrings",
        "Packages/SukunKit/Sources/SukunKit/Resources/Localizable.xcstrings",
    ]

    private func placeholders(_ s: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(lld|@)"#)
        return regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
            .map { String(s[Range($0.range(at: 1), in: s)!]) }
            .sorted()
    }

    func testEveryStringHasGermanAndArabicWithMatchingPlaceholders() throws {
        for path in catalogs {
            let data = try Data(contentsOf: repoRoot.appendingPathComponent(path))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])
            for (key, entry) in strings {
                let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
                let english = (localizations["en"]?["stringUnit"] as? [String: String])?["value"] ?? key
                for language in ["de", "ar"] {
                    let value = (localizations[language]?["stringUnit"] as? [String: String])?["value"]
                    XCTAssertFalse(value?.isEmpty ?? true, "\(path): '\(key)' has no \(language) value")
                    if let value {
                        XCTAssertEqual(placeholders(value), placeholders(english), "\(path): '\(key)' (\(language)) placeholders differ")
                    }
                }
            }
        }
    }

    func testArabicPrayerNamesShipInTheKitBundle() throws {
        let path = try XCTUnwrap(Bundle.module.path(forResource: "ar", ofType: "lproj"), "ar.lproj missing in SukunKit")
        let bundle = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(bundle.localizedString(forKey: "prayer.fajr", value: nil, table: nil), "الفجر")
        XCTAssertEqual(bundle.localizedString(forKey: "prayer.maghrib", value: nil, table: nil), "المغرب")
    }
}
