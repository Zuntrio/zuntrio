/// Modifier keys of a shortcut, independent of AppKit/Carbon.
public struct ShortcutModifiers: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let shift = ShortcutModifiers(rawValue: 1 << 2)
    public static let command = ShortcutModifiers(rawValue: 1 << 3)

    /// Symbols in Apple's canonical order: ⌃⌥⇧⌘.
    public var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }

    /// Words for VoiceOver, in the same order: "Control Option Shift Command".
    public var spokenNames: [String] {
        var names: [String] = []
        if contains(.control) { names.append("Control") }
        if contains(.option) { names.append("Option") }
        if contains(.shift) { names.append("Shift") }
        if contains(.command) { names.append("Command") }
        return names
    }
}

/// A key plus modifiers. `keyCode` is a macOS virtual key code (the values of
/// Carbon's `kVK_*` constants), kept as a plain number so this stays platform-free.
public struct KeyCombo: Sendable, Hashable, Codable {
    public let keyCode: UInt16
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt16, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public enum Key {
        public static let c: UInt16 = 8
        public static let f: UInt16 = 3
        public static let z: UInt16 = 6
        public static let u: UInt16 = 32
        public static let i: UInt16 = 34
        public static let j: UInt16 = 38
        public static let k: UInt16 = 40
        public static let returnKey: UInt16 = 36
        public static let equal: UInt16 = 24
        public static let minus: UInt16 = 27
        public static let leftArrow: UInt16 = 123
        public static let rightArrow: UInt16 = 124
        public static let downArrow: UInt16 = 125
        public static let upArrow: UInt16 = 126
    }

    public var displayString: String {
        modifiers.symbols + Self.keyName(keyCode)
    }

    /// For VoiceOver, which reads glyphs such as ⌥ or ← poorly: "Option Command Left Arrow".
    public var spokenDescription: String {
        (modifiers.spokenNames + [Self.spokenKeyName(keyCode)]).joined(separator: " ")
    }

    /// Why this combination can't be used as a global shortcut, if anything.
    public var validationIssue: ShortcutIssue? {
        // Plain keys or Shift/Option-only combos would hijack typing; macOS 15.0
        // also rejected Option-only and Option+Shift-only hotkeys.
        modifiers.isDisjoint(with: [.command, .control]) ? .needsCommandOrControl : nil
    }

    /// Names for keys on an ANSI layout, by virtual key code.
    static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func keyName(_ code: UInt16) -> String {
        keyNames[code] ?? "Key \(code)"
    }

    /// Spoken names for keys whose display name is a symbol.
    static let spokenKeyNames: [UInt16: String] = [
        24: "Equals", 27: "Minus", 30: "Right Bracket", 33: "Left Bracket", 36: "Return", 39: "Apostrophe",
        41: "Semicolon", 42: "Backslash", 43: "Comma", 44: "Slash", 47: "Period", 48: "Tab",
        50: "Grave Accent", 51: "Delete", 53: "Escape",
        123: "Left Arrow", 124: "Right Arrow", 125: "Down Arrow", 126: "Up Arrow",
    ]

    public static func spokenKeyName(_ code: UInt16) -> String {
        spokenKeyNames[code] ?? keyName(code)
    }
}

public enum ShortcutIssue: Sendable, Equatable {
    case needsCommandOrControl
    /// Already used by another Zuntrio action.
    case usedByAction(WindowAction)
    /// Matches an enabled macOS keyboard shortcut (System Settings → Keyboard → Keyboard Shortcuts).
    case reservedBySystem
}

/// A named set of default shortcuts.
public enum ShortcutPreset: String, Sendable, CaseIterable, Codable {
    /// Spectacle's defaults (ADR-0005). The out-of-the-box choice.
    case spectacle
    /// ⌃⌥-based alternative that leaves ⌥⌘←/→ to browsers' tab switching.
    case alternative

    public var displayName: String {
        switch self {
        case .spectacle: "Spectacle"
        case .alternative: "Alternative (⌃⌥)"
        }
    }

    public var bindings: [WindowAction: KeyCombo] {
        switch self {
        case .spectacle: DefaultShortcuts.spectacle
        case .alternative: DefaultShortcuts.alternative
        }
    }
}

/// Default shortcut maps. Every combination includes ⌘ or ⌃.
public enum DefaultShortcuts {
    public static let spectacle: [WindowAction: KeyCombo] = {
        typealias K = KeyCombo.Key
        let cmdOpt: ShortcutModifiers = [.command, .option]
        let ctrlCmd: ShortcutModifiers = [.control, .command]
        let ctrlShiftCmd: ShortcutModifiers = [.control, .shift, .command]
        let ctrlOpt: ShortcutModifiers = [.control, .option]
        let ctrlOptShift: ShortcutModifiers = [.control, .option, .shift]
        let ctrlOptCmd: ShortcutModifiers = [.control, .option, .command]
        return [
            .undo: KeyCombo(keyCode: K.z, modifiers: cmdOpt),
            .redo: KeyCombo(keyCode: K.z, modifiers: [.option, .shift, .command]),
            .center: KeyCombo(keyCode: K.c, modifiers: cmdOpt),
            .maximize: KeyCombo(keyCode: K.f, modifiers: cmdOpt),
            .leftHalf: KeyCombo(keyCode: K.leftArrow, modifiers: cmdOpt),
            .rightHalf: KeyCombo(keyCode: K.rightArrow, modifiers: cmdOpt),
            .topHalf: KeyCombo(keyCode: K.upArrow, modifiers: cmdOpt),
            .bottomHalf: KeyCombo(keyCode: K.downArrow, modifiers: cmdOpt),
            .upperLeft: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlCmd),
            .upperRight: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlCmd),
            .lowerLeft: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlShiftCmd),
            .lowerRight: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlShiftCmd),
            .nextThird: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlOpt),
            .previousThird: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlOpt),
            .larger: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlOptShift),
            .smaller: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlOptShift),
            .nextDisplay: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlOptCmd),
            .previousDisplay: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlOptCmd),
        ]
    }()

    /// Alternative preset: ⌃⌥ + arrows for halves, ⌃⌥ + U/I/J/K for corners
    /// (laid out like the corners of the screen), so ⌥⌘ stays free for apps.
    public static let alternative: [WindowAction: KeyCombo] = {
        typealias K = KeyCombo.Key
        let ctrlOpt: ShortcutModifiers = [.control, .option]
        let ctrlOptShift: ShortcutModifiers = [.control, .option, .shift]
        let ctrlOptCmd: ShortcutModifiers = [.control, .option, .command]
        return [
            .undo: KeyCombo(keyCode: K.z, modifiers: ctrlOpt),
            .redo: KeyCombo(keyCode: K.z, modifiers: ctrlOptShift),
            .center: KeyCombo(keyCode: K.c, modifiers: ctrlOpt),
            .maximize: KeyCombo(keyCode: K.returnKey, modifiers: ctrlOpt),
            .leftHalf: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlOpt),
            .rightHalf: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlOpt),
            .topHalf: KeyCombo(keyCode: K.upArrow, modifiers: ctrlOpt),
            .bottomHalf: KeyCombo(keyCode: K.downArrow, modifiers: ctrlOpt),
            .upperLeft: KeyCombo(keyCode: K.u, modifiers: ctrlOpt),
            .upperRight: KeyCombo(keyCode: K.i, modifiers: ctrlOpt),
            .lowerLeft: KeyCombo(keyCode: K.j, modifiers: ctrlOpt),
            .lowerRight: KeyCombo(keyCode: K.k, modifiers: ctrlOpt),
            .nextThird: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlOptShift),
            .previousThird: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlOptShift),
            .larger: KeyCombo(keyCode: K.equal, modifiers: ctrlOpt),
            .smaller: KeyCombo(keyCode: K.minus, modifiers: ctrlOpt),
            .nextDisplay: KeyCombo(keyCode: K.rightArrow, modifiers: ctrlOptCmd),
            .previousDisplay: KeyCombo(keyCode: K.leftArrow, modifiers: ctrlOptCmd),
        ]
    }()
}
