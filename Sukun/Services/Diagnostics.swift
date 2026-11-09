import StoreKit

/// Tester tools (pending reminders, reschedule log) appear in debug and TestFlight builds, never on the App Store.
enum Diagnostics {
    static func isAvailable() async -> Bool {
        #if DEBUG
        return true
        #else
        // TestFlight reports the sandbox environment. Accept an unverified answer too: this only reveals a tester
        // screen, it unlocks nothing, and TestFlight sometimes can't verify the transaction right away.
        guard let result = try? await AppTransaction.shared else { return false }
        let environment: AppStore.Environment
        switch result {
        case .verified(let transaction), .unverified(let transaction, _): environment = transaction.environment
        }
        return environment == .sandbox || environment == .xcode
        #endif
    }
}
