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
    /// Returns the actual system status, or falls back to stored preference
    static var isEnabled: Bool {
        get {
            // Check actual system status first
            let status = loginItem.status
            switch status {
            case .enabled:
                return true
            case .notRegistered, .notFound:
                return false
            case .requiresApproval:
                // User needs to approve in System Settings
                return UserDefaults.standard.bool(forKey: preferenceKey)
            @unknown default:
                return UserDefaults.standard.bool(forKey: preferenceKey)
            }
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
    /// - Returns: Whether the operation succeeded
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        // Store the user's preference first
        UserDefaults.standard.set(enabled, forKey: preferenceKey)
        
        do {
            if enabled {
                try loginItem.register()
            } else {
                try loginItem.unregister()
            }
            
            print("LaunchAtLoginService: Successfully \(enabled ? "enabled" : "disabled") launch at login. Status: \(loginItem.status)")
            return true
        } catch {
            // Log the error - SMAppService can fail for various reasons
            // Common reasons: app not properly signed, running from debug location, etc.
            print("LaunchAtLoginService: Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            print("LaunchAtLoginService: Current status: \(loginItem.status)")
            print("LaunchAtLoginService: Note - This often fails for debug builds. Install the Release build in /Applications for full functionality.")
            return false
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
