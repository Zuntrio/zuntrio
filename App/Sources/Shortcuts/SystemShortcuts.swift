import Carbon.HIToolbox
import ZuntrioCore

/// Reads the enabled macOS keyboard shortcuts (System Settings → Keyboard →
/// Keyboard Shortcuts: Mission Control, Spaces, screenshots, …) so Zuntrio can
/// warn when one of its shortcuts matches. Read-only; nothing is changed.
enum SystemShortcuts {
    static func enabledCombos() -> Set<KeyCombo> {
        var unmanaged: Unmanaged<CFArray>?
        let status = CopySymbolicHotKeys(&unmanaged)
        guard status == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else {
            Log.shortcuts.error("CopySymbolicHotKeys failed: \(status)")
            return []
        }
        var result: Set<KeyCombo> = []
        for entry in array {
            // Keys are the CFSTR values of kHISymbolicHotKey*, which Swift doesn't import.
            guard (entry["kHISymbolicHotKeyEnabled"] as? Bool) == true,
                  let code = entry["kHISymbolicHotKeyCode"] as? Int, code >= 0, code < 0xFFFF,
                  let carbonModifiers = entry["kHISymbolicHotKeyModifiers"] as? Int else { continue }
            // The Fn flag means Fn/Globe must be held (macOS lists entries on
            // bare arrows with only that flag, and a key-press test showed
            // ⌃⌥⇧→ reaching Zuntrio, not the matching Fn-flagged tiling entry).
            // Zuntrio can't register Globe shortcuts, so these never collide.
            if carbonModifiers & Int(kEventKeyModifierFnMask) != 0 { continue }
            result.insert(KeyCombo(keyCode: UInt16(code), modifiers: modifiers(fromCarbon: carbonModifiers)))
        }
        return result
    }

    static func modifiers(fromCarbon mask: Int) -> ShortcutModifiers {
        var modifiers: ShortcutModifiers = []
        if mask & cmdKey != 0 { modifiers.insert(.command) }
        if mask & optionKey != 0 { modifiers.insert(.option) }
        if mask & controlKey != 0 { modifiers.insert(.control) }
        if mask & shiftKey != 0 { modifiers.insert(.shift) }
        return modifiers
    }

    static func carbonModifiers(_ modifiers: ShortcutModifiers) -> UInt32 {
        var mask = 0
        if modifiers.contains(.command) { mask |= cmdKey }
        if modifiers.contains(.option) { mask |= optionKey }
        if modifiers.contains(.control) { mask |= controlKey }
        if modifiers.contains(.shift) { mask |= shiftKey }
        return UInt32(mask)
    }
}
