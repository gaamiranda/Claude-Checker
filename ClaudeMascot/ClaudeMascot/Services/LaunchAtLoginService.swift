import Foundation
import ServiceManagement

/// Service for managing launch at login functionality
enum LaunchAtLoginService {
    
    /// UserDefaults key for storing the launch at login preference
    private static let preferenceKey = "launchAtLogin"
    
    /// The main app's login item service
    private static var loginItem: SMAppService {
        SMAppService.mainApp
    }
    
    // MARK: - Public API
    
    /// Whether launch at login is currently enabled
    static var isEnabled: Bool {
        get {
            loginItem.status == .enabled
        }
        set {
            setEnabled(newValue)
        }
    }
    
    /// Whether the user has explicitly set a preference (vs first launch)
    static var hasUserPreference: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) != nil
    }
    
    /// Enable or disable launch at login
    /// - Parameter enabled: Whether to enable launch at login
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try loginItem.register()
            } else {
                try loginItem.unregister()
            }
            
            // Store the user's preference
            UserDefaults.standard.set(enabled, forKey: preferenceKey)
        } catch {
            // Log but don't throw - SMAppService can fail silently in some cases
            print("LaunchAtLoginService: Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
    
    /// Initialize launch at login on first app launch
    /// If no preference exists, enables launch at login by default
    static func initializeOnFirstLaunch() {
        if !hasUserPreference {
            // Enable by default on first launch (per DEPLOYMENT.md)
            setEnabled(true)
        }
    }
}
