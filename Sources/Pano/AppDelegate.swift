import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: FloatingPanel?
    private var searchText: String = ""
    private var previousApp: NSRunningApplication?
    private var globalClickMonitor: Any?
    private var previewPanel: ImagePreviewPanel?
    private var previewMouseMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupWorkspaceObserver()
        setupStatusItem()
        setupPanel()
        setupHotkey()
        ClipboardMonitor.shared.start()
    }

    private func setupWorkspaceObserver() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = app
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pano") {
            image.isTemplate = true
            button.image = image
        }

        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPanel() {
        let initialSize = SettingsManager.shared.windowSizeOption.size
        let panelRect = NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height)

        let floatingPanel = FloatingPanel(contentRect: panelRect)
        floatingPanel.alphaValue = 1.0

        let contentView = ClipboardListView(
            searchText: Binding(
                get: { [weak self] in self?.searchText ?? "" },
                set: { [weak self] newValue in
                    self?.searchText = newValue
                    SelectionManager.shared.reset()
                }
            ),
            onSelectItem: { [weak self] item in
                self?.hideImagePreview()
                self?.selectAndPaste(item: item)
            },
            onClose: { [weak self] in
                self?.hideImagePreview()
                self?.hidePanel()
            },
            onPreviewItem: { [weak self] item in
                self?.showImagePreview(for: item)
            },
            onDismissPreview: { [weak self] in
                self?.hideImagePreview()
            },
            onHeightChange: { [weak self] newHeight in
                self?.adjustPanelHeight(newHeight)
            }
        )

        floatingPanel.contentView = NSHostingView(rootView: contentView)

        floatingPanel.onEscape = { [weak self] in
            self?.hidePanel()
        }

        floatingPanel.onArrowDown = { [weak self] in
            guard let self = self else { return }
            let count = self.getFilteredItems().count
            SelectionManager.shared.moveDown(totalCount: count)
        }

        floatingPanel.onArrowUp = { [weak self] in
            guard let self = self else { return }
            let count = self.getFilteredItems().count
            SelectionManager.shared.moveUp(totalCount: count)
        }

        floatingPanel.onReturnKey = { [weak self] in
            guard let self = self else { return }
            let filtered = self.getFilteredItems()
            let index = SelectionManager.shared.selectedIndex
            if index >= 0 && index < filtered.count {
                self.selectAndPaste(item: filtered[index])
            }
        }

        floatingPanel.onNumberShortcut = { [weak self] number in
            guard let self = self else { return }
            let filtered = self.getFilteredItems()
            let index = number - 1
            if index >= 0 && index < filtered.count {
                self.selectAndPaste(item: filtered[index])
            }
        }

        floatingPanel.isSearchEmpty = { [weak self] in
            return self?.searchText.isEmpty ?? true
        }

        floatingPanel.onDeleteKey = { [weak self] in
            guard let self = self else { return }
            let filtered = self.getFilteredItems()
            let index = SelectionManager.shared.selectedIndex
            if index >= 0 && index < filtered.count {
                let itemToDelete = filtered[index]
                ClipboardStore.shared.delete(id: itemToDelete.id)
                let newFiltered = self.getFilteredItems()
                SelectionManager.shared.clamp(totalCount: newFiltered.count)
                self.hideImagePreview()
            }
        }

        floatingPanel.onMouseMoved = { [weak self] mouseLocation in
            self?.updatePreviewPosition(at: mouseLocation)
        }

        SettingsManager.shared.onSizeChanged = { [weak self] newOption in
            self?.updateWindowSize(option: newOption)
        }

        SettingsManager.shared.onOpacityChanged = { [weak self] _ in
            // Window background opacity is handled inside SwiftUI view to keep texts sharp and opaque
            self?.panel?.alphaValue = 1.0
        }

        self.panel = floatingPanel
    }

    public func adjustPanelHeight(_ newHeight: CGFloat) {
        guard let panel = self.panel else { return }
        let currentFrame = panel.frame
        let targetHeight = ceil(newHeight)
        if abs(currentFrame.height - targetHeight) < 1 { return }

        // Anchor window at the top: keep maxY constant
        let oldTop = currentFrame.maxY
        let newY = oldTop - targetHeight

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        let clampedY = max(visible.minY + 8, min(newY, visible.maxY - targetHeight - 8))

        let newFrame = NSRect(x: currentFrame.origin.x, y: clampedY, width: currentFrame.width, height: targetHeight)
        panel.setFrame(newFrame, display: true, animate: panel.isVisible)
    }

    public func updateWindowSize(option: WindowSizeOption) {
        guard let panel = self.panel else { return }
        let currentFrame = panel.frame
        let targetWidth = option.width
        let targetHeight = min(currentFrame.height, option.maxHeight)

        let oldTop = currentFrame.maxY
        let oldMidX = currentFrame.midX

        var newX = oldMidX - (targetWidth / 2)
        var newY = oldTop - targetHeight

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        newX = max(visible.minX + 8, min(newX, visible.maxX - targetWidth - 8))
        newY = max(visible.minY + 8, min(newY, visible.maxY - targetHeight - 8))

        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        panel.setFrame(newFrame, display: true, animate: true)
    }

    public func getFilteredItems() -> [ClipboardItem] {
        let store = ClipboardStore.shared
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.items
        } else {
            return store.items.filter { item in
                item.preview.localizedCaseInsensitiveContains(searchText) ||
                (item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    private func setupHotkey() {
        GlobalHotkeyManager.shared.onHotKeyPressed = { [weak self] in
            self?.togglePanel(atCursor: true)
        }
        GlobalHotkeyManager.shared.registerDefaultHotkeys()
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel(atCursor: false)
        }
    }

    public func togglePanel(atCursor: Bool = true) {
        guard let panel = panel else { return }

        if panel.isVisible {
            hidePanel()
        } else {
            showPanel(atCursor: atCursor)
        }
    }

    public func showPanel(atCursor: Bool = true) {
        guard let panel = panel else { return }

        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontApp
        }

        searchText = ""
        SelectionManager.shared.reset()

        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let visibleFrame = activeScreen.visibleFrame

        var targetPoint: NSPoint

        if atCursor {
            var x = mouseLocation.x - (panel.frame.width / 2)
            var y: CGFloat
            if (mouseLocation.y - panel.frame.height - 12) >= visibleFrame.minY {
                y = mouseLocation.y - panel.frame.height - 12
            } else {
                y = mouseLocation.y + 12
            }

            x = max(visibleFrame.minX + 8, min(x, visibleFrame.maxX - panel.frame.width - 8))
            y = max(visibleFrame.minY + 8, min(y, visibleFrame.maxY - panel.frame.height - 8))
            targetPoint = NSPoint(x: x, y: y)
        } else {
            if let button = statusItem?.button, let window = button.window {
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = window.convertToScreen(buttonRect)
                var x = screenRect.midX - (panel.frame.width / 2)
                var y = screenRect.minY - panel.frame.height - 6
                x = max(visibleFrame.minX + 8, min(x, visibleFrame.maxX - panel.frame.width - 8))
                y = max(visibleFrame.minY + 8, min(y, visibleFrame.maxY - panel.frame.height - 8))
                targetPoint = NSPoint(x: x, y: y)
            } else {
                targetPoint = NSPoint(
                    x: visibleFrame.midX - (panel.frame.width / 2),
                    y: visibleFrame.midY - (panel.frame.height / 2)
                )
            }
        }

        panel.setFrameOrigin(targetPoint)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startGlobalClickMonitor()
    }

    public func hidePanel() {
        hideImagePreview()
        stopGlobalClickMonitor()
        panel?.orderOut(nil)
    }

    public func showImagePreview(for item: ClipboardItem) {
        guard SettingsManager.shared.previewTrigger != .disabled else { return }
        guard let mainPanel = self.panel, mainPanel.isVisible else { return }

        if previewPanel == nil {
            previewPanel = ImagePreviewPanel()
        }

        guard let preview = previewPanel else { return }
        preview.update(with: item)

        let previewSize = ImagePreviewPanel.calculateSize(for: item)
        let mouseLocation = NSEvent.mouseLocation

        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? mainPanel.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let visible = screen.visibleFrame

        // Anchor directly to the right of the mouse cursor
        let cursorOffset: CGFloat = 16
        var x = mouseLocation.x + cursorOffset

        // If not enough room to the right of the cursor, flip to the left of the cursor
        if x + previewSize.width > visible.maxX - 8 {
            x = mouseLocation.x - previewSize.width - cursorOffset
        }

        // Center vertically around the cursor
        var y = mouseLocation.y - (previewSize.height / 2)
        y = max(visible.minY + 8, min(y, visible.maxY - previewSize.height - 8))

        preview.setFrame(NSRect(x: x, y: y, width: previewSize.width, height: previewSize.height), display: true)

        if !preview.isVisible {
            if preview.parent == nil {
                mainPanel.addChildWindow(preview, ordered: .above)
            }
            preview.orderFront(nil)
        }

        startPreviewMouseMonitor()
    }

    public func hideImagePreview() {
        stopPreviewMouseMonitor()
        if let preview = previewPanel, preview.isVisible {
            preview.orderOut(nil)
        }
    }

    public func updatePreviewPosition(at mouseLocation: NSPoint) {
        guard let preview = previewPanel, preview.isVisible, let mainPanel = self.panel else { return }

        // If cursor left the main window, close preview immediately
        if !mainPanel.frame.contains(mouseLocation) {
            hideImagePreview()
            return
        }

        let previewSize = preview.frame.size
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? mainPanel.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let visible = screen.visibleFrame

        let cursorOffset: CGFloat = 16
        var x = mouseLocation.x + cursorOffset

        if x + previewSize.width > visible.maxX - 8 {
            x = mouseLocation.x - previewSize.width - cursorOffset
        }

        var y = mouseLocation.y - (previewSize.height / 2)
        y = max(visible.minY + 8, min(y, visible.maxY - previewSize.height - 8))

        preview.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startPreviewMouseMonitor() {
        stopPreviewMouseMonitor()
        previewMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self = self, let mainPanel = self.panel, self.previewPanel?.isVisible == true else { return }
            let mouseLoc = NSEvent.mouseLocation
            if !mainPanel.frame.contains(mouseLoc) {
                self.hideImagePreview()
            }
        }
    }

    private func stopPreviewMouseMonitor() {
        if let monitor = previewMouseMonitor {
            NSEvent.removeMonitor(monitor)
            previewMouseMonitor = nil
        }
    }

    private func startGlobalClickMonitor() {
        stopGlobalClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let panel = self.panel, panel.isVisible else { return }
            let clickLoc = NSEvent.mouseLocation

            let isInsidePreview = self.previewPanel?.frame.contains(clickLoc) ?? false
            if !panel.frame.contains(clickLoc) && !isInsidePreview {
                if let button = self.statusItem?.button, let win = button.window {
                    let btnRect = win.convertToScreen(button.convert(button.bounds, to: nil))
                    if btnRect.contains(clickLoc) {
                        return
                    }
                }
                // Don't close if a popup menu is currently active
                if NSApp.windows.contains(where: { $0 != panel && $0 != self.previewPanel && ($0.className.contains("Menu") || $0.className.contains("PopUp")) }) {
                    return
                }
                self.hidePanel()
            }
        }
    }

    private func stopGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    private func selectAndPaste(item: ClipboardItem) {
        hidePanel()
        let targetApp = previousApp
        PasteService.shared.selectAndCopy(item: item, previousApp: targetApp)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pano (v1.0)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Sabitlenmeyenleri Temizle", action: #selector(clearHistoryAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Çıkış", action: #selector(quitAction), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }

    @objc private func clearHistoryAction() {
        ClipboardStore.shared.clearUnpinned()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
