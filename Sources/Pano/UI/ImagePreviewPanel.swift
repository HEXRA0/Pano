import AppKit
import SwiftUI

public final class ImagePreviewPanel: NSPanel {
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
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
    }

    override public var canBecomeKey: Bool {
        return false
    }

    override public var canBecomeMain: Bool {
        return false
    }

    public func update(with item: ClipboardItem) {
        self.contentView = NSHostingView(rootView: ImagePreviewView(item: item))
    }

    public static func calculateSize(for item: ClipboardItem) -> CGSize {
        var imageSize = CGSize(width: 300, height: 220)

        if let data = item.imageData, let img = NSImage(data: data) {
            imageSize = img.size
        } else if let paths = item.filePaths, let first = paths.first, let img = NSImage(contentsOfFile: first) {
            imageSize = img.size
        }

        let previewOption = SettingsManager.shared.previewSize
        let dims = previewOption.maxDimensions
        let maxW: CGFloat = dims.maxW
        let maxH: CGFloat = dims.maxH
        let minW: CGFloat = max(160, maxW * 0.6)
        let minH: CGFloat = max(120, maxH * 0.6)
        let chromeHeight: CGFloat = 48 // Header and footer combined

        guard imageSize.width > 0 && imageSize.height > 0 else {
            return CGSize(width: minW, height: minH)
        }

        let ratio = imageSize.width / imageSize.height

        var targetW: CGFloat
        var targetH: CGFloat

        if ratio >= 1.0 {
            // Landscape
            targetW = min(maxW, max(minW, imageSize.width))
            targetH = (targetW / ratio) + chromeHeight
            if targetH > maxH {
                targetH = maxH
                targetW = (targetH - chromeHeight) * ratio
            }
        } else {
            // Portrait
            targetH = min(maxH, max(minH, imageSize.height + chromeHeight))
            targetW = (targetH - chromeHeight) * ratio
            if targetW < minW {
                targetW = minW
            }
            if targetW > maxW {
                targetW = maxW
                targetH = (targetW / ratio) + chromeHeight
            }
        }

        return CGSize(
            width: max(minW, min(maxW, targetW)),
            height: max(minH, min(maxH, targetH))
        )
    }
}

public struct ImagePreviewView: View {
    let item: ClipboardItem
    @ObservedObject var settings = SettingsManager.shared

    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 6) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.purple)

                Text("Önizleme")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if let nsImage = itemImage {
                    Text("\(Int(nsImage.size.width)) × \(Int(nsImage.size.height))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }
            }

            // Image Display
            if let nsImage = itemImage {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))

                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(6)
                        .padding(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1.5)
            } else {
                Spacer()
                Text("Görsel yüklenemedi")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Footer Bar
            HStack {
                Text(item.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                if let data = item.imageData {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    .opacity(settings.previewOpacity)
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.18 * settings.previewOpacity)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12 * max(0.6, settings.previewOpacity)), lineWidth: 0.5)
        )
    }

    private var itemImage: NSImage? {
        if let data = item.imageData {
            return NSImage(data: data)
        }
        if let paths = item.filePaths, let first = paths.first {
            let ext = (first as NSString).pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic"].contains(ext) {
                return NSImage(contentsOfFile: first)
            }
        }
        return nil
    }
}
