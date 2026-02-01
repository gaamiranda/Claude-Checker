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
    
    /// Error message if last fetch failed
    var errorMessage: String?
    
    /// Timestamp of last successful data fetch
    var lastUpdated: Date?
    
    // MARK: - Computed Properties
    
    /// Color for the menu bar icon based on session usage
    var statusColor: Color {
        // Gray if there's an error
        if errorMessage != nil {
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
        
        do {
            // Get credentials
            let credentials = try KeychainService.getCredentials()
            planTier = credentials.planDisplayName
            
            // Fetch usage data
            let usage = try await apiClient.fetchUsage(token: credentials.accessToken)
            
            // Update state with fetched data
            sessionPercentage = usage.fiveHour ?? 0
            weeklyPercentage = usage.sevenDay ?? 0
            sonnetPercentage = usage.sevenDaySonnet ?? 0
            
            if let extra = usage.extraUsage {
                extraSpend = extra.spend
                extraLimit = extra.limit
            } else {
                extraSpend = 0
                extraLimit = 0
            }
            
            lastUpdated = Date()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Deinit
    
    deinit {
        refreshTask?.cancel()
    }
}
