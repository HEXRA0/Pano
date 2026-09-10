import Foundation
import AppKit
import ServiceManagement

public enum WindowSizeOption: String, CaseIterable, Identifiable, Codable {
    case mini
    case compact
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .mini: return "Mini (280 × 340)"
        case .compact: return "Kompakt (310 × 390)"
        case .small: return "Küçük (340 × 440)"
        case .medium: return "Standart (380 × 500)"
        case .large: return "Büyük (440 × 580)"
        }
    }

    public var width: CGFloat {
        switch self {
        case .mini: return 280
        case .compact: return 310
        case .small: return 340
        case .medium: return 380
        case .large: return 440
        }
    }

    public var maxHeight: CGFloat {
        switch self {
        case .mini: return 340
        case .compact: return 390
        case .small: return 440
        case .medium: return 500
        case .large: return 580
        }
    }

    public var size: CGSize {
        CGSize(width: width, height: maxHeight)
    }
}

public enum PreviewTrigger: String, CaseIterable, Identifiable, Codable {
    case fullRow = "fullRow"
    case thumbnailOnly = "thumbnailOnly"
    case disabled = "disabled"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fullRow: return "Tüm Satırın Üzerine Gelince"
        case .thumbnailOnly: return "Yalnızca Küçük İkonun/Görselin Üzerine Gelince"
        case .disabled: return "Önizlemeyi Gösterme"
        }
    }
}

public enum PreviewSize: String, CaseIterable, Identifiable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: return "Küçük Önizleme (240 × 180)"
        case .medium: return "Standart Önizleme (320 × 260)"
        case .large: return "Büyük Önizleme (420 × 340)"
        }
    }

    public var maxDimensions: (maxW: CGFloat, maxH: CGFloat) {
        switch self {
        case .small: return (240, 180)
        case .medium: return (320, 260)
        case .large: return (420, 340)
        }
    }
}

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    @Published public var launchAtLogin: Bool = false
    @Published public var windowOpacity: Double = 0.85
    @Published public var windowSizeOption: WindowSizeOption = .medium

    // Preview Settings
    @Published public var previewTrigger: PreviewTrigger = .fullRow
    @Published public var previewSize: PreviewSize = .medium
    @Published public var previewOpacity: Double = 0.95

    public var onSizeChanged: ((WindowSizeOption) -> Void)?
    public var onOpacityChanged: ((Double) -> Void)?

    private let opacityKey = "pano_window_opacity"
    private let sizeKey = "pano_window_size"
    private let previewTriggerKey = "pano_preview_trigger"
    private let previewSizeKey = "pano_preview_size"
    private let previewOpacityKey = "pano_preview_opacity"

    private init() {
        checkStatus()
        loadPreferences()
    }

    private func loadPreferences() {
        let savedOpacity = UserDefaults.standard.double(forKey: opacityKey)
        if savedOpacity >= 0.20 && savedOpacity <= 1.0 {
            self.windowOpacity = savedOpacity
        } else {
            self.windowOpacity = 0.85
        }

        if let savedSizeStr = UserDefaults.standard.string(forKey: sizeKey),
           let savedSize = WindowSizeOption(rawValue: savedSizeStr) {
            self.windowSizeOption = savedSize
        } else {
            self.windowSizeOption = .medium
        }

        if let savedTriggerStr = UserDefaults.standard.string(forKey: previewTriggerKey),
           let savedTrigger = PreviewTrigger(rawValue: savedTriggerStr) {
            self.previewTrigger = savedTrigger
        } else {
            self.previewTrigger = .fullRow
        }

        if let savedPreviewSizeStr = UserDefaults.standard.string(forKey: previewSizeKey),
           let savedPreviewSize = PreviewSize(rawValue: savedPreviewSizeStr) {
            self.previewSize = savedPreviewSize
        } else {
            self.previewSize = .medium
        }

        let savedPrevOpacity = UserDefaults.standard.double(forKey: previewOpacityKey)
        if savedPrevOpacity >= 0.20 && savedPrevOpacity <= 1.0 {
            self.previewOpacity = savedPrevOpacity
        } else {
            self.previewOpacity = 0.95
        }
    }

    public func setPreviewTrigger(_ trigger: PreviewTrigger) {
        self.previewTrigger = trigger
        UserDefaults.standard.set(trigger.rawValue, forKey: previewTriggerKey)
    }

    public func setPreviewSize(_ size: PreviewSize) {
        self.previewSize = size
        UserDefaults.standard.set(size.rawValue, forKey: previewSizeKey)
    }

    public func setPreviewOpacity(_ opacity: Double) {
        self.previewOpacity = opacity
        UserDefaults.standard.set(opacity, forKey: previewOpacityKey)
    }

    public func setOpacity(_ opacity: Double) {
        self.windowOpacity = opacity
        UserDefaults.standard.set(opacity, forKey: opacityKey)
        onOpacityChanged?(opacity)
    }

    public func setWindowSize(_ option: WindowSizeOption) {
        self.windowSizeOption = option
        UserDefaults.standard.set(option.rawValue, forKey: sizeKey)
        onSizeChanged?(option)
    }

    public func checkStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    public func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    launchAtLogin = false
                } else {
                    try SMAppService.mainApp.register()
                    launchAtLogin = true
                }
            } catch {
                print("SettingsManager: Error toggling launch at login: \(error)")
            }
        }
    }
}
