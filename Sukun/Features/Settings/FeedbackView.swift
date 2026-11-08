import SukunKit
import SwiftUI

/// Native feedback form. Sent anonymously to PostHog only when the user taps Send.
struct FeedbackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var service = FeedbackService()

    @State private var kind: FeedbackKind = .idea
    @State private var text = ""
    @State private var includeDiagnostics = true
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: LocalizedStringKey?
    @FocusState private var textFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Group {
                if didSend {
                    sentView
                } else {
                    form
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .sensoryFeedback(.success, trigger: didSend)
        .interactiveDismissDisabled(isSending || (!text.isEmpty && !didSend))
    }

    private var form: some View {
        Form {
            Section {
                Picker("Type", selection: $kind) {
                    ForEach(FeedbackKind.allCases) { kind in
                        Text(kind.localizedName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(6...14)
                    .focused($textFocused)
                    .accessibilityLabel(Text("Your feedback"))
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Toggle("Include technical details", isOn: $includeDiagnostics)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if includeDiagnostics {
                        Text("App version, iOS version, device model, language and calculation method. Never your location.")
                    }
                    Text("Sent anonymously. If you’d like a reply, write to support@sukun.faith.")
                }
            }
        }
        .onAppear { textFocused = true }
    }

    private var placeholder: LocalizedStringKey {
        switch kind {
        case .idea: "What would make Sukun better for you?"
        case .problem: "What happened, and what did you expect?"
        case .wrongTimes: "Which prayer, which city, and what time does your mosque use?"
        }
    }

    private var sentView: some View {
        ContentUnavailableView {
            Label("Thank you", systemImage: "checkmark.circle")
                .foregroundStyle(Palette.accentText)
        } description: {
            Text("Your feedback has been sent.")
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !didSend {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSending)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSending {
                    ProgressView()
                } else {
                    Button("Send") { Task { await send() } }
                        .disabled(!canSend)
                }
            }
        }
    }

    private func send() async {
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        let diagnostics = includeDiagnostics
            ? FeedbackDiagnostics.current(settings: model.settings, location: model.location)
            : nil
        do {
            try await service.send(kind: kind, text: text, diagnostics: diagnostics)
            didSend = true
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            errorMessage = "No connection. Your text is kept, try again later."
        } catch {
            errorMessage = "Couldn’t send right now. Your text is kept, try again later."
        }
    }
}
