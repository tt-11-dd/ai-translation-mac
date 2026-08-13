import AppKit
import Carbon

final class HotKeyManager {
    static let shared = HotKeyManager()

    static let toggleID: UInt32 = 1
    static let selectionID: UInt32 = 2
    static let screenshotID: UInt32 = 3

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    private init() {}

    func register(_ slots: [(id: UInt32, config: HotKeyConfig, handler: () -> Void)]) {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard err == noErr else { return noErr }
                DispatchQueue.main.async {
                    manager.handlers[hotKeyID.id]?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            NSLog("HotKeyManager: InstallEventHandler failed: \(status)")
            return
        }

        for slot in slots {
            handlers[slot.id] = slot.handler
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x41495452), id: slot.id)
            let registerStatus = RegisterEventHotKey(
                slot.config.keyCode,
                slot.config.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if registerStatus != noErr {
                NSLog("HotKeyManager: RegisterEventHotKey \(slot.id) failed: \(registerStatus)")
            } else {
                refs[slot.id] = ref
            }
        }
    }

    func unregister() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        handlers.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
