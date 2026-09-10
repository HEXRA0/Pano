import Foundation
import AppKit
import ServiceManagement

public enum WindowSizeOption: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large
    case extraLarge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: return "Küçük (340 × 430)"
        case .medium: return "Standart (380 × 490)"
        case .large: return "Büyük (440 × 580)"
        case .extraLarge: return "Geniş (500 × 660)"
        }
    }

    public var size: CGSize {
        switch self {
        case .small: return CGSize(width: 340, height: 430)
        case .medium: return CGSize(width: 380, height: 490)
        case .large: return CGSize(width: 440, height: 580)
        case .extraLarge: return CGSize(width: 500, height: 660)
        }
    }
}

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    @Published public var launchAtLogin: Bool = false
    @Published public var windowOpacity: Double = 0.95
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
        if savedOpacity >= 0.5 && savedOpacity <= 1.0 {
            self.windowOpacity = savedOpacity
        } else {
            self.windowOpacity = 0.95
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
