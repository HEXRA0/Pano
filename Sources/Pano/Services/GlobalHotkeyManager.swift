import Carbon
import Foundation

@MainActor
public final class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()

    public var onHotKeyPressed: (() -> Void)?
    private var hotKeyRefs: [EventHotKeyRef] = []

    private init() {}

    public func registerDefaultHotkeys() {
        // Event type for hotkey pressed
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, _, _ -> OSStatus in
            Task { @MainActor in
                GlobalHotkeyManager.shared.onHotKeyPressed?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            nil
        )

        let modifiers = UInt32(cmdKey | shiftKey)

        // 1. Register Shift + Command + C (0x08)
        let hotKeyID1 = EventHotKeyID(signature: OSType(0x50414E4F), id: 1) // 'PANO'
        var ref1: EventHotKeyRef?
        let status1 = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            modifiers,
            hotKeyID1,
            GetApplicationEventTarget(),
            0,
            &ref1
        )
        if status1 == noErr, let r = ref1 {
            hotKeyRefs.append(r)
            print("GlobalHotkeyManager: Registered ⇧⌘C hotkey")
        } else {
            print("GlobalHotkeyManager: Failed to register ⇧⌘C (\(status1))")
        }

        // 2. Register Shift + Command + V (0x09)
        let hotKeyID2 = EventHotKeyID(signature: OSType(0x50414E4F), id: 2) // 'PANO'
        var ref2: EventHotKeyRef?
        let status2 = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            modifiers,
            hotKeyID2,
            GetApplicationEventTarget(),
            0,
            &ref2
        )
        if status2 == noErr, let r = ref2 {
            hotKeyRefs.append(r)
            print("GlobalHotkeyManager: Registered ⇧⌘V hotkey")
        } else {
            print("GlobalHotkeyManager: Failed to register ⇧⌘V (\(status2))")
        }
    }

    public func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }
}
