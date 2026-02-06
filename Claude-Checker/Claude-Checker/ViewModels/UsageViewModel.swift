import SwiftUI

/// Main view model for managing Claude usage data and state
@Observable
class UsageViewModel {
    
    // MARK: - Usage Data
    
    /// Session (5-hour window) usage percentage (0.0-1.0)
    var sessionPercentage: Double = 0
    
    /// Weekly (7-day) aggregate usage percentage (0.0-1.0)
    var weeklyPercentage: Double = 0
    
    /// Sonnet-specific weekly usage percentage (0.0-1.0)
    var sonnetPercentage: Double = 0
    
    /// Extra usage spend in dollars
    var extraSpend: Double = 0
    
    /// Extra usage limit in dollars
    var extraLimit: Double = 0
    
    /// User's plan tier (Max, Pro, Team, Enterprise)
    var planTier: String = "Unknown"
    
    // MARK: - State
    
    /// Whether data is currently being fetched
    var isLoading = false
    
    /// Whether this is the first load (no data yet)
    var isFirstLoad = true
    
    /// Error message if last fetch failed
    var errorMessage: String?
    
    /// Whether the error requires user to re-authenticate
    var requiresReauthentication = false
    
    /// Timestamp of last successful data fetch
    var lastUpdated: Date?
    
    /// Reset time for session window (parsed from API)
    var sessionResetsAt: Date?
    
    /// Reset time for weekly window (parsed from API)
    var weeklyResetsAt: Date?
    
    /// Whether the app should launch at login (stored locally for UI binding)
    var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "launchAtLogin") {
        didSet {
            if launchAtLogin != oldValue {
                LaunchAtLoginService.setEnabled(launchAtLogin)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Color for the menu bar icon based on session usage
    var statusColor: Color {
        // Gray if loading for the first time or error
        if isFirstLoad || errorMessage != nil {
            return .gray
        }
        
        // Color based on session percentage
        switch sessionPercentage {
        case 0..<0.3:
            return .green
        case 0.3..<0.7:
            return .blue
        default:
            return .red
        }
    }
    
    /// Whether extra usage data is available
    var hasExtraUsage: Bool {
        extraLimit > 0
    }
    
    /// Extra usage percentage (0.0-1.0)
    var extraPercentage: Double {
        guard extraLimit > 0 else { return 0 }
        return min(extraSpend / extraLimit, 1.0)
    }
    
    // MARK: - Private Properties
    
    private let apiClient = UsageAPIClient()
    private var refreshTask: Task<Void, Never>?
    
    /// Refresh interval in seconds (5 minutes)
    private let refreshInterval: TimeInterval = 300
    
    // MARK: - Public Methods
    
    /// Starts automatic refresh timer
    func startAutoRefresh() {
        // Cancel any existing task
        refreshTask?.cancel()
        
        refreshTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Initial fetch
            await self.refresh()
            
            // Continue refreshing while not cancelled
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                
                if !Task.isCancelled {
                    await self.refresh()
                }
            }
        }
    }
    
    /// Stops automatic refresh timer
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    /// Manually refreshes usage data
    @MainActor
    func refresh() async {
        // Don't refresh if already loading
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        requiresReauthentication = false
        
        // Check if credentials file has changed (user ran `claude login`)
        KeychainService.invalidateCacheIfNeeded()
        
        do {
            // Get credentials (may be from cache if recently refreshed)
            let credentials = try KeychainService.getCredentials()
            planTier = credentials.planDisplayName
            
            // Fetch usage data with automatic token refresh
            let (usage, updatedCredentials) = try await apiClient.fetchUsage(credentials: credentials)
            
            // Update plan tier in case it changed after token refresh
            planTier = updatedCredentials.planDisplayName
            
            // Update state with fetched data
            sessionPercentage = usage.fiveHour?.percentage ?? 0
            weeklyPercentage = usage.sevenDay?.percentage ?? 0
            sonnetPercentage = usage.sevenDaySonnet?.percentage ?? 0
            
            // Parse reset times
            sessionResetsAt = parseResetTime(usage.fiveHour?.resetsAt)
            weeklyResetsAt = parseResetTime(usage.sevenDay?.resetsAt)
            
            if let extra = usage.extraUsage, extra.hasData {
                extraSpend = extra.spend
                extraLimit = extra.limit
            } else {
                extraSpend = 0
                extraLimit = 0
            }
            
            lastUpdated = Date()
            isFirstLoad = false
            
        } catch let error as APIError {
            handleError(error)
        } catch let error as CredentialError {
            handleCredentialError(error)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Deinit
    
    deinit {
        refreshTask?.cancel()
    }
    
    // MARK: - Private Helpers
    
    /// Handles API errors with specific messaging
    private func handleError(_ error: APIError) {
        errorMessage = error.localizedDescription
        requiresReauthentication = error.requiresReauthentication
        
        // If re-authentication is required, clear the cache so next attempt reads fresh
        if error.requiresReauthentication {
            KeychainService.clearCache()
        }
    }
    
    /// Handles credential errors
    private func handleCredentialError(_ error: CredentialError) {
        errorMessage = error.localizedDescription
        
        switch error {
        case .notFound, .tokenExpired:
            requiresReauthentication = true
        case .refreshFailed:
            requiresReauthentication = true
            KeychainService.clearCache()
        default:
            requiresReauthentication = false
        }
    }
    
    /// Parses ISO8601 date string from API
    private func parseResetTime(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}
