import Carbon.HIToolbox

enum HotKeyError: Error, CustomStringConvertible {
    case installHandlerFailed(OSStatus)
    case registrationFailed(OSStatus)

    var description: String {
        switch self {
        case .installHandlerFailed(let status): "event handler install failed, OSStatus \(status)"
        case .registrationFailed(let status):
            status == OSStatus(eventHotKeyExistsErr)
                ? "already used by another app (OSStatus \(status))"
                : "OSStatus \(status)"
        }
    }
}

/// Global hotkeys via Carbon `RegisterEventHotKey`, which does not require
/// Input Monitoring permission. Handlers run on the main thread.
@MainActor
final class HotKeyCenter {
    /// Four-char code 'ZNTR' identifying our hotkeys.
    private static let signature: OSType = 0x5A4E_5452

    private var handlers: [UInt32: () -> Void] = [:]
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// The Carbon callback is a C function and can't capture context; it
    /// dispatches to the instance that installed the handler.
    fileprivate static weak var active: HotKeyCenter?

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) throws(HotKeyError) -> UInt32 {
        try installEventHandlerIfNeeded()

        let id = nextID
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers, EventHotKeyID(signature: Self.signature, id: id),
            GetEventDispatcherTarget(), 0, &reference
        )
        guard status == noErr, let reference else { throw .registrationFailed(status) }

        nextID += 1
        handlers[id] = handler
        references[id] = reference
        return id
    }

    func unregister(_ id: UInt32) {
        if let reference = references.removeValue(forKey: id) {
            let status = UnregisterEventHotKey(reference)
            if status != noErr {
                Log.shortcuts.error("UnregisterEventHotKey failed: \(status)")
            }
        }
        handlers[id] = nil
    }

    fileprivate func handle(id: UInt32) {
        handlers[id]?()
    }

    private func installEventHandlerIfNeeded() throws(HotKeyError) {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(), hotKeyCallback, 1, &eventType, nil, &eventHandler
        )
        guard status == noErr else { throw .installHandlerFailed(status) }
        Self.active = self
    }
}

/// C callback. Carbon delivers hotkey events on the main thread's event loop.
private func hotKeyCallback(_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr else { return status }
    let id = hotKeyID.id
    MainActor.assumeIsolated {
        HotKeyCenter.active?.handle(id: id)
    }
    return noErr
}
