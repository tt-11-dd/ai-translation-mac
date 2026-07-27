import AppKit
import Carbon
import ApplicationServices

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var mouseGlobalMonitor: Any?
    private var mouseLocalMonitor: Any?
    private var handler: (() -> Void)?
    private var currentConfig: HotKeyConfig?

    private let hotKeyID = EventHotKeyID(signature: OSType(0x41495452), id: 1) // 'AITR'

    private init() {}

    func register(config: HotKeyConfig, handler: @escaping () -> Void) {
        unregister()
        self.handler = handler
        self.currentConfig = config

        switch config.kind {
        case .keyboard:
            registerKeyboard(config)
        case .mouseMiddle:
            registerMouseMiddle(config)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let mouseGlobalMonitor {
            NSEvent.removeMonitor(mouseGlobalMonitor)
            self.mouseGlobalMonitor = nil
        }
        if let mouseLocalMonitor {
            NSEvent.removeMonitor(mouseLocalMonitor)
            self.mouseLocalMonitor = nil
        }
        handler = nil
        currentConfig = nil
    }

    private func registerKeyboard(_ config: HotKeyConfig) {
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
                guard err == noErr, hotKeyID.id == manager.hotKeyID.id else {
                    return noErr
                }

                DispatchQueue.main.async {
                    manager.handler?()
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

        let registerStatus = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            NSLog("HotKeyManager: RegisterEventHotKey failed: \(registerStatus)")
        }
    }

    private func registerMouseMiddle(_ config: HotKeyConfig) {
        // 全局鼠标监听需要辅助功能权限
        if !AccessibilityHelper.isTrusted {
            AccessibilityHelper.requestTrust()
        }

        let fire: (NSEvent) -> Void = { [weak self] event in
            guard let self, let current = self.currentConfig else { return }
            guard current.matchesMouseEvent(event) else { return }
            DispatchQueue.main.async {
                self.handler?()
            }
        }

        mouseGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { event in
            fire(event)
        }

        mouseLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
            if config.matchesMouseEvent(event) {
                fire(event)
            }
            return event
        }

        if mouseGlobalMonitor == nil {
            NSLog("HotKeyManager: 全局鼠标监听失败，请在「系统设置 → 隐私与安全性 → 辅助功能」中允许本应用")
        }
    }

    deinit {
        unregister()
    }
}
