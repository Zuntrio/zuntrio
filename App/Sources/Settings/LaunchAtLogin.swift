import ServiceManagement

/// Launch at login via `SMAppService.mainApp` (macOS 13+). Off by default;
/// only changed when the user flips the switch.
@MainActor
enum LaunchAtLogin {
    enum State: Equatable {
        case enabled
        case disabled
        /// Registered, but the user must allow it in System Settings → General → Login Items.
        case requiresApproval
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
