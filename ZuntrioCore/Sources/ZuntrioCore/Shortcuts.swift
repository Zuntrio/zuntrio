/// Modifier keys of a shortcut, independent of AppKit/Carbon.
public struct ShortcutModifiers: OptionSet, Sendable, Hashable {
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
}

/// A key plus modifiers. `keyCode` is a macOS virtual key code (the values of
/// Carbon's `kVK_*` constants), kept as a plain number so this stays platform-free.
public struct KeyCombo: Sendable, Hashable {
    public let keyCode: UInt16
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt16, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public enum Key {
        public static let c: UInt16 = 0x08
        public static let f: UInt16 = 0x03
        public static let z: UInt16 = 0x06
        public static let leftArrow: UInt16 = 0x7B
        public static let rightArrow: UInt16 = 0x7C
        public static let downArrow: UInt16 = 0x7D
        public static let upArrow: UInt16 = 0x7E
    }

    public var displayString: String {
        modifiers.symbols + Self.keyName(keyCode)
    }

    static func keyName(_ code: UInt16) -> String {
        switch code {
        case Key.c: "C"
        case Key.f: "F"
        case Key.z: "Z"
        case Key.leftArrow: "←"
        case Key.rightArrow: "→"
        case Key.downArrow: "↓"
        case Key.upArrow: "↑"
        default: "key \(code)"
        }
    }
}

/// Default shortcut map: Spectacle's defaults (ADR-0005). All include ⌘ or ⌃,
/// avoiding the Option-only combinations macOS 15 restricted.
public enum DefaultShortcuts {
    public static let spectacle: [LayoutAction: KeyCombo] = {
        typealias K = KeyCombo.Key
        let cmdOpt: ShortcutModifiers = [.command, .option]
        let ctrlCmd: ShortcutModifiers = [.control, .command]
        let ctrlShiftCmd: ShortcutModifiers = [.control, .shift, .command]
        let ctrlOpt: ShortcutModifiers = [.control, .option]
        let ctrlOptShift: ShortcutModifiers = [.control, .option, .shift]
        let ctrlOptCmd: ShortcutModifiers = [.control, .option, .command]
        return [
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
}
