import AppKit

@MainActor
public final class PasteService {
    public static let shared = PasteService()

    private init() {}

    public func copyToPasteboard(item: ClipboardItem) {
        ClipboardMonitor.shared.markSelfCopy()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            if let rtf = item.rtfData {
                pasteboard.setData(rtf, forType: .rtf)
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .fileURL:
            if let paths = item.filePaths {
                let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
                pasteboard.writeObjects(urls)
            }
        case .rtf:
            if let rtf = item.rtfData {
                pasteboard.setData(rtf, forType: .rtf)
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        }
    }

    public func selectAndCopy(item: ClipboardItem, previousApp: NSRunningApplication?) {
        copyToPasteboard(item: item)

        // Deactivate Pano so macOS returns focus to the target application
        NSApp.deactivate()

        if let targetApp = previousApp, !targetApp.isTerminated {
            targetApp.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
