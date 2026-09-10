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

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    @Published public var launchAtLogin: Bool = false
    @Published public var windowOpacity: Double = 0.85
    @Published public var windowSizeOption: WindowSizeOption = .medium

    public var onSizeChanged: ((WindowSizeOption) -> Void)?
    public var onOpacityChanged: ((Double) -> Void)?

    private let opacityKey = "pano_window_opacity"
    private let sizeKey = "pano_window_size"

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
