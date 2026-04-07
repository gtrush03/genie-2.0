import AppKit
import Carbon
import os

final class GlobalHotkey {
    static let shared = GlobalHotkey()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "hotkey")
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    /// Register Cmd+Shift+G as a global hotkey
    func register(action: @escaping () -> Void) {
        callback = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerRef = UnsafeMutablePointer<GlobalHotkey>.allocate(capacity: 1)
        handlerRef.initialize(to: self)

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotkey = userData.assumingMemoryBound(to: GlobalHotkey.self).pointee
                DispatchQueue.main.async {
                    hotkey.callback?()
                }
                return noErr
            },
            1,
            &eventType,
            handlerRef,
            &eventHandler
        )

        // Cmd+Shift+G: modifier = cmdKey | shiftKey, keyCode = 5 (G key)
        let hotkeyID = EventHotKeyID(signature: OSType(0x474E4945), id: 1) // "GNIE"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_G),
            UInt32(cmdKey | shiftKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        logger.info("Global hotkey registered: Cmd+Shift+G")
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        logger.info("Global hotkey unregistered")
    }

    deinit {
        unregister()
    }
}
