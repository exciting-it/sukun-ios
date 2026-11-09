import Foundation
import SukunKit
import UIKit

/// Where feedback goes: a PostHog survey of type "API" in the EU cloud.
/// No SDK, no analytics: exactly one HTTPS request, only when the user taps Send.
/// The project key is write-only and meant to ship in clients.
struct FeedbackConfig: Sendable {
    var captureURL: URL
    var apiKey: String
    var surveyID: String
    var textQuestionID: String
    var kindQuestionID: String
    /// App Store "Apple ID" of the app, for the "Rate Sukun" link. nil hides the row.
    var appStoreID: String?

    static let production = FeedbackConfig(
        captureURL: URL(string: "https://eu.i.posthog.com/i/v0/e/")!,
        apiKey: "phc_vy8ogSkTcMA2k3fGabXNTCuv4qYCTgMQUw3RZ4KLUeUj",
        surveyID: "01a1bcef-4f96-0000-3cce-9416c0b05a96",
        textQuestionID: "c20f5df2-5355-45ec-8093-1d79bbe8b1ff",
        kindQuestionID: "d4113404-b61f-47f4-a66e-058f851a67fb",
        appStoreID: "6832348832"
    )

    var writeReviewURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}

enum FeedbackKind: String, CaseIterable, Identifiable, Sendable {
    // Raw values must match the choices of the PostHog survey question.
    case idea = "Idea"
    case problem = "Problem"
    case wrongTimes = "Wrong prayer times"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .idea: String(localized: "Idea")
        case .problem: String(localized: "Problem")
        case .wrongTimes: String(localized: "Wrong times")
        }
    }
}

/// Technical details the user can choose to attach. Deliberately no location, coordinates or city.
struct FeedbackDiagnostics: Equatable, Sendable {
    var appVersion: String
    var osVersion: String
    var deviceModel: String
    var language: String
    var calculationMethod: String?

    var properties: [String: String] {
        var result = [
            "app_version": appVersion,
            "os_version": osVersion,
            "device_model": deviceModel,
            "language": language,
        ]
        if let calculationMethod { result["calculation_method"] = calculationMethod }
        return result
    }

    @MainActor
    static func current(settings: SukunSettings, location: StoredLocation?) -> FeedbackDiagnostics {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let method = location.map { CalculationConfiguration(settings: settings, location: $0).method.rawValue }
        return FeedbackDiagnostics(
            appVersion: "\(version) (\(build))",
            osVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            deviceModel: Self.machineIdentifier(),
            language: Locale.preferredLanguages.first ?? Locale.current.identifier,
            calculationMethod: method
        )
    }

    /// e.g. "iPhone17,2" (UIDevice.model only says "iPhone").
    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

enum FeedbackError: Error, Equatable {
    case emptyText
    case server(status: Int)
}

struct FeedbackService: Sendable {
    var config: FeedbackConfig = .production
    var session: URLSession = .shared

    /// Builds the PostHog capture request for one survey response.
    /// Each submission gets a fresh random id and no person profile, so submissions can't be linked.
    func request(
        kind: FeedbackKind,
        text: String,
        diagnostics: FeedbackDiagnostics?,
        submissionID: UUID = UUID(),
        date: Date = Date()
    ) throws -> URLRequest {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FeedbackError.emptyText }

        var properties: [String: Any] = [
            "$survey_id": config.surveyID,
            "$survey_submission_id": submissionID.uuidString,
            "$survey_completed": true,
            "$survey_response_\(config.textQuestionID)": trimmed,
            "$survey_response_\(config.kindQuestionID)": kind.rawValue,
            "$survey_questions": [
                ["id": config.textQuestionID, "question": "Feedback"],
                ["id": config.kindQuestionID, "question": "Type"],
            ],
            "$process_person_profile": false,
            "$lib": "sukun-ios",
        ]
        diagnostics?.properties.forEach { properties[$0.key] = $0.value }

        let body: [String: Any] = [
            "api_key": config.apiKey,
            "event": "survey sent",
            "distinct_id": submissionID.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: date),
            "properties": properties,
        ]

        var request = URLRequest(url: config.captureURL, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }

    func send(kind: FeedbackKind, text: String, diagnostics: FeedbackDiagnostics?) async throws {
        let request = try request(kind: kind, text: text, diagnostics: diagnostics)
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw FeedbackError.server(status: status) }
    }
}
