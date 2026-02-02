import SwiftUI

/// View model for managing Cursor usage data and state
@Observable
class CursorViewModel {
    
    // MARK: - Usage Data
    
    /// Plan usage percentage (0.0-1.0)
    var planPercentage: Double = 0
    
    /// Plan used in USD
    var planUsedUSD: Double = 0
    
    /// Plan limit in USD
    var planLimitUSD: Double = 0
    
    /// On-demand used in USD
    var onDemandUsedUSD: Double = 0
    
    /// On-demand limit in USD (nil if unlimited)
    var onDemandLimitUSD: Double?
    
    /// When the billing period resets
    var billingResetsAt: Date?
    
    /// Membership type (Pro, Hobby, Enterprise, etc.)
    var membershipType: String = "Unknown"
    
    /// User email (optional)
    var userEmail: String?
    
    // MARK: - State
    
    /// Whether data is currently being fetched
    var isLoading = false
    
    /// Whether this is the first load (no data yet)
    var isFirstLoad = true
    
    /// Error message if last fetch failed
    var errorMessage: String?
    
    /// Timestamp of last successful data fetch
    var lastUpdated: Date?
    
    // MARK: - Configuration
    
    /// Cookie header for UI binding (when pasting)
    var cookieInput: String = ""
    
    // MARK: - Computed Properties
    
    /// Whether Cursor is configured with a cookie
    var isConfigured: Bool {
        CursorCookieService.hasCookie
    }
    
    /// Whether on-demand has a spending limit
    var hasOnDemandLimit: Bool {
        onDemandLimitUSD != nil && onDemandLimitUSD! > 0
    }
    
    /// On-demand usage percentage (0.0-1.0) - only valid if hasOnDemandLimit
    var onDemandPercentage: Double {
        guard let limit = onDemandLimitUSD, limit > 0 else { return 0 }
        return min(onDemandUsedUSD / limit, 1.0)
    }
    
    /// Formatted plan usage string
    var planUsageText: String {
        String(format: "$%.2f / $%.2f", planUsedUSD, planLimitUSD)
    }
    
    /// Formatted on-demand usage string
    var onDemandUsageText: String {
        if let limit = onDemandLimitUSD {
            return String(format: "$%.2f / $%.2f", onDemandUsedUSD, limit)
        }
        return String(format: "$%.2f", onDemandUsedUSD)
    }
    
    /// Whether there's any on-demand usage to display
    var hasOnDemandUsage: Bool {
        onDemandUsedUSD > 0 || hasOnDemandLimit
    }
    
    // MARK: - Private Properties
    
    private let apiClient = CursorAPIClient()
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
            
            // Initial fetch (only if configured)
            if self.isConfigured {
                await self.refresh()
            }
            
            // Continue refreshing while not cancelled
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                
                if !Task.isCancelled && self.isConfigured {
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
        // Don't refresh if not configured or already loading
        guard isConfigured else {
            errorMessage = "Please configure your Cursor cookie first."
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get cookie
            guard let cookie = CursorCookieService.getCookieHeader() else {
                throw CursorAPIError.noCookieConfigured
            }
            
            // Fetch usage summary
            let summary = try await apiClient.fetchUsageSummary(cookie: cookie)
            
            // Update state with fetched data
            membershipType = summary.membershipDisplayName
            billingResetsAt = summary.billingEndDate
            
            // Plan usage
            // Always use default plan limit based on membership type
            // The API's limit field is unreliable (often equals used amount)
            planLimitUSD = summary.defaultPlanLimitUSD
            
            if let plan = summary.individualUsage?.plan {
                planUsedUSD = plan.usedUSD
                
                // Calculate percentage based on the membership limit
                if planLimitUSD > 0 {
                    planPercentage = min(planUsedUSD / planLimitUSD, 1.0)
                } else if let totalPercent = plan.totalPercentUsed {
                    // Fall back to API percentage if available (for unknown plans)
                    planPercentage = totalPercent <= 1 ? totalPercent : totalPercent / 100.0
                } else {
                    planPercentage = 0
                }
            } else {
                planPercentage = 0
                planUsedUSD = 0
            }
            
            // On-demand usage
            if let onDemand = summary.individualUsage?.onDemand {
                onDemandUsedUSD = onDemand.usedUSD
                onDemandLimitUSD = onDemand.limitUSD
            } else {
                onDemandUsedUSD = 0
                onDemandLimitUSD = nil
            }
            
            // Try to fetch user info (optional)
            if let userInfo = try? await apiClient.fetchUserInfo(cookie: cookie) {
                userEmail = userInfo.email
            }
            
            lastUpdated = Date()
            isFirstLoad = false
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Saves the cookie from user input
    @MainActor
    func saveCookie() {
        let trimmed = cookieInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please paste a cookie value."
            return
        }
        
        CursorCookieService.saveCookieHeader(trimmed)
        cookieInput = ""
        errorMessage = nil
        
        // Trigger a refresh
        Task {
            await refresh()
        }
    }
    
    /// Clears the stored cookie
    @MainActor
    func clearCookie() {
        CursorCookieService.clearCookieHeader()
        
        // Reset state
        planPercentage = 0
        planUsedUSD = 0
        planLimitUSD = 0
        onDemandUsedUSD = 0
        onDemandLimitUSD = nil
        billingResetsAt = nil
        membershipType = "Unknown"
        userEmail = nil
        lastUpdated = nil
        isFirstLoad = true
        errorMessage = nil
    }
    
    // MARK: - Deinit
    
    deinit {
        refreshTask?.cancel()
    }
}
