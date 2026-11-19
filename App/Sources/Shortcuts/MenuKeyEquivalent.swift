import AppKit
import Carbon.HIToolbox
import ZuntrioCore

/// Turns a shortcut into an NSMenuItem key equivalent, so menus show it in the
/// standard right-hand column. Display only: the status menu doesn't act on
/// these keys (see `StatusMenuController.menuHasKeyEquivalent`).
enum MenuKeyEquivalent {
    static func apply(_ combo: KeyCombo?, to item: NSMenuItem) {
        guard let combo, let key = character(for: combo.keyCode) else { return }
        item.keyEquivalent = key
        var flags: NSEvent.ModifierFlags = []
        if combo.modifiers.contains(.command) { flags.insert(.command) }
        if combo.modifiers.contains(.option) { flags.insert(.option) }
        if combo.modifiers.contains(.control) { flags.insert(.control) }
        if combo.modifiers.contains(.shift) { flags.insert(.shift) }
        item.keyEquivalentModifierMask = flags
    }

    private static func character(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_LeftArrow: "\u{F702}"
        case kVK_RightArrow: "\u{F703}"
        case kVK_UpArrow: "\u{F700}"
        case kVK_DownArrow: "\u{F701}"
        case kVK_Return: "\r"
        case kVK_Tab: "\t"
        case kVK_Space: " "
        case kVK_Delete: "\u{8}"
        case kVK_Escape: "\u{1B}"
        default:
            KeyCombo.keyName(keyCode).count == 1 ? KeyCombo.keyName(keyCode).lowercased() : nil
        }
    }
}
