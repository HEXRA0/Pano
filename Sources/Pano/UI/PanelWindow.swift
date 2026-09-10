import AppKit
import SwiftUI

public final class FloatingPanel: NSPanel {
    public var onEscape: (() -> Void)?
    public var onNumberShortcut: ((Int) -> Void)?
    public var onArrowDown: (() -> Void)?
    public var onArrowUp: (() -> Void)?
    public var onReturnKey: (() -> Void)?
    public var onDeleteKey: (() -> Void)?
    public var isSearchEmpty: (() -> Bool)?
    public var onMouseMoved: ((NSPoint) -> Void)?

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
    }

    override public var canBecomeKey: Bool {
        return true
    }

    override public var canBecomeMain: Bool {
        return true
    }

    override public func resignKey() {
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !NSApp.isActive {
                self.orderOut(nil)
            }
        }
    }

    override public func sendEvent(_ event: NSEvent) {
        if event.type == .mouseMoved {
            onMouseMoved?(NSEvent.mouseLocation)
        }

        if event.type == .keyDown {
            // Escape key (53)
            if event.keyCode == 53 {
                onEscape?()
                self.orderOut(nil)
                return
            }

            // Down Arrow (125)
            if event.keyCode == 125 {
                onArrowDown?()
                return
            }

            // Up Arrow (126)
            if event.keyCode == 126 {
                onArrowUp?()
                return
            }

            // Return / Enter (36, 76)
            if event.keyCode == 36 || event.keyCode == 76 {
                onReturnKey?()
                return
            }

            // Delete keys: 51 (Backspace/Delete), 117 (Forward Delete)
            if event.keyCode == 51 || event.keyCode == 117 {
                // Command+Backspace or Option+Backspace: always delete selected item
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                    onDeleteKey?()
                    return
                }
                // When search field is empty, plain Backspace deletes selected item
                if isSearchEmpty?() == true {
                    onDeleteKey?()
                    return
                }
            }

            // Check for Command + 1..9
            if event.modifierFlags.contains(.command) {
                if let chars = event.charactersIgnoringModifiers,
                   let number = Int(chars),
                   number >= 1 && number <= 9 {
                    onNumberShortcut?(number)
                    return
                }
            }
        }

        super.sendEvent(event)
    }
}
