import Foundation
import LocalAuthentication

enum BiometricAuth {
    static func confirm(reason: String = "Confirm changing whether this Mac sleeps when the lid is closed.") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            policy = .deviceOwnerAuthentication
        } else {
            throw AuthError.unavailable
        }

        let ok = try await context.evaluatePolicy(policy, localizedReason: reason)
        guard ok else { throw AuthError.failed }
    }

    enum AuthError: Error {
        case unavailable
        case failed
    }
}
