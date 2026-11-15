import Foundation
import Observation
import ServiceManagement

/// Wraps `SMAppService.mainApp` for the "Open at login" toggle.
@Observable
@MainActor
final class LoginItemController {
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    /// On if registered, including while macOS waits for the user's approval.
    var isOn: Bool {
        status == .enabled || status == .requiresApproval
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// Opens System Settings → General → Login Items.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
