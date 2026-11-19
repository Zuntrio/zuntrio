import os

/// Logging rules: action names, outcomes, AX error codes and geometry only.
/// Never log window titles, document names, app names/bundle IDs or keystrokes.
enum Log {
    private static let subsystem = "app.zuntrio.Zuntrio"
    static let actions = Logger(subsystem: subsystem, category: "actions")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let shortcuts = Logger(subsystem: subsystem, category: "shortcuts")
    static let accessibility = Logger(subsystem: subsystem, category: "accessibility")
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
