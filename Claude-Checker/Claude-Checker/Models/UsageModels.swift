import Foundation

/// Response from the Anthropic OAuth usage endpoint
struct UsageResponse: Codable {
    /// Session window (5-hour) usage
    let fiveHour: UsageWindow?
    
    /// Weekly aggregate (7-day) usage
    let sevenDay: UsageWindow?
    
    /// Sonnet-specific weekly usage
    let sevenDaySonnet: UsageWindow?
    
    /// Opus-specific weekly usage (ignored for now)
    let sevenDayOpus: UsageWindow?
    
    /// OAuth apps specific usage
    let sevenDayOauthApps: UsageWindow?
    
    /// Cowork usage
    let sevenDayCowork: UsageWindow?
    
    /// Extra usage cost information
    let extraUsage: ExtraUsage?
    
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayCowork = "seven_day_cowork"
        case extraUsage = "extra_usage"
    }
}

/// Usage window with utilization percentage and reset time
struct UsageWindow: Codable {
    /// Utilization percentage (0-100)
    let utilization: Double?
    
    /// When this window resets
    let resetsAt: String?
    
    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
    
    /// Utilization as a fraction (0.0-1.0)
    var percentage: Double {
        guard let util = utilization else { return 0 }
        return min(util / 100.0, 1.0)
    }
}

/// Extra usage cost data (monthly spend tracking)
struct ExtraUsage: Codable {
    /// Whether extra usage is enabled
    let isEnabled: Bool?
    
    /// Monthly spending limit in dollars
    let monthlyLimit: Double?
    
    /// Credits used
    let usedCredits: Double?
    
    /// Utilization percentage (0-100)
    let utilization: Double?
    
    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }
    
    /// Whether extra usage data is available and enabled
    var hasData: Bool {
        isEnabled == true && monthlyLimit != nil
    }
    
    /// Spend amount (used_credits or 0)
    var spend: Double {
        usedCredits ?? 0
    }
    
    /// Limit amount (monthly_limit or 0)
    var limit: Double {
        monthlyLimit ?? 0
    }
    
    /// Percentage of limit used (0.0-1.0)
    var percentage: Double {
        guard let util = utilization else {
            guard limit > 0 else { return 0 }
            return min(spend / limit, 1.0)
        }
        return min(util / 100.0, 1.0)
    }
}
