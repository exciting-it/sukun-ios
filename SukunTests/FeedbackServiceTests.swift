import XCTest
@testable import Sukun

final class FeedbackServiceTests: XCTestCase {
    private let service = FeedbackService()
    private let diagnostics = FeedbackDiagnostics(
        appVersion: "1.0.0 (3)", osVersion: "iOS 27.2", deviceModel: "iPhone19,2",
        language: "de-DE", calculationMethod: "muslimWorldLeague"
    )

    private func json(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    func testBuildsSurveyResponseForPostHogEU() throws {
        let id = UUID()
        let request = try service.request(kind: .wrongTimes, text: "  Isha is 5 min early in Munich \n",
                                          diagnostics: diagnostics, submissionID: id)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.host(), "eu.i.posthog.com")

        let body = try json(request)
        XCTAssertEqual(body["event"] as? String, "survey sent")
        XCTAssertEqual(body["distinct_id"] as? String, id.uuidString)
        XCTAssertEqual(body["api_key"] as? String, FeedbackConfig.production.apiKey)

        let props = try XCTUnwrap(body["properties"] as? [String: Any])
        let config = FeedbackConfig.production
        XCTAssertEqual(props["$survey_id"] as? String, config.surveyID)
        XCTAssertEqual(props["$survey_response_\(config.textQuestionID)"] as? String, "Isha is 5 min early in Munich")
        XCTAssertEqual(props["$survey_response_\(config.kindQuestionID)"] as? String, "Wrong prayer times")
        XCTAssertEqual(props["$process_person_profile"] as? Bool, false)
        XCTAssertEqual(props["calculation_method"] as? String, "muslimWorldLeague")
    }

    func testDiagnosticsAreOptionalAndNeverContainLocation() throws {
        let without = try json(service.request(kind: .idea, text: "Hi", diagnostics: nil))
        let props = try XCTUnwrap(without["properties"] as? [String: Any])
        XCTAssertNil(props["app_version"])
        XCTAssertNil(props["device_model"])

        let with = try json(service.request(kind: .idea, text: "Hi", diagnostics: diagnostics))
        let keys = Set(try XCTUnwrap(with["properties"] as? [String: Any]).keys)
        for forbidden in ["latitude", "longitude", "coordinate", "city", "location"] {
            XCTAssertFalse(keys.contains { $0.localizedCaseInsensitiveContains(forbidden) }, forbidden)
        }
    }

    func testProductionRateLinkPointsToSukun() {
        XCTAssertEqual(FeedbackConfig.production.writeReviewURL?.absoluteString,
                       "https://apps.apple.com/app/id6832348832?action=write-review")
    }

    func testEmptyTextIsRejected() {
        XCTAssertThrowsError(try service.request(kind: .problem, text: "   \n", diagnostics: nil)) { error in
            XCTAssertEqual(error as? FeedbackError, .emptyText)
        }
    }

    func testSubmissionsAreNotLinkable() throws {
        let a = try json(service.request(kind: .idea, text: "a", diagnostics: nil))
        let b = try json(service.request(kind: .idea, text: "b", diagnostics: nil))
        XCTAssertNotEqual(a["distinct_id"] as? String, b["distinct_id"] as? String)
    }

    func testKindRawValuesMatchSurveyChoices() {
        XCTAssertEqual(FeedbackKind.allCases.map(\.rawValue), ["Idea", "Problem", "Wrong prayer times"])
    }

    func testReviewLinkHiddenWithoutAppStoreID() {
        var config = FeedbackConfig.production
        config.appStoreID = nil
        XCTAssertNil(config.writeReviewURL)
        config.appStoreID = "123456789"
        XCTAssertEqual(config.writeReviewURL?.absoluteString, "https://apps.apple.com/app/id123456789?action=write-review")
    }
}
