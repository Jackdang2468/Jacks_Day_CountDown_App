import Foundation
import LocalAuthentication
import Observation

/// Optional Face ID / Touch ID / passcode lock for the app.
@MainActor
@Observable
final class AppLock {
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "lock.enabled") }
    }
    private(set) var isLocked: Bool
    var errorMessage: String?

    init() {
        let enabled = UserDefaults.standard.bool(forKey: "lock.enabled")
        isEnabled = enabled
        isLocked = enabled
    }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    func lock() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isLocked else { return }
        let context = LAContext()
        do {
            // Falls back to the device passcode if Face ID fails.
            if try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Day Counter") {
                isLocked = false
                errorMessage = nil
            }
        } catch {
            errorMessage = (error as? LAError)?.code == .userCancel ? nil : error.localizedDescription
        }
    }

    /// Confirms with Face ID before turning the lock on, so it's known to work.
    func setEnabled(_ enabled: Bool) async {
        guard enabled else {
            isEnabled = false
            return
        }
        let context = LAContext()
        let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Turn on app lock")) ?? false
        isEnabled = ok
    }
}
