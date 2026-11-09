import StoreKit

/// Tester tools (pending reminders, reschedule log) appear in debug and TestFlight builds, never on the App Store.
enum Diagnostics {
    static func isAvailable() async -> Bool {
        #if DEBUG
        return true
        #else
        guard let result = try? await AppTransaction.shared, case .verified(let transaction) = result else { return false }
        return transaction.environment == .sandbox || transaction.environment == .xcode
        #endif
    }
}
