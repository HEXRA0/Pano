import Foundation
import ServiceManagement

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    @Published public var launchAtLogin: Bool = false

    private init() {
        checkStatus()
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
