import Foundation

/// Response from the Anthropic OAuth usage endpoint
struct UsageResponse: Codable {
    /// Session window (5-hour) usage percentage (0.0-1.0)
    let fiveHour: Double?
    
    /// Weekly aggregate (7-day) usage percentage (0.0-1.0)
    let sevenDay: Double?
    
    /// Sonnet-specific weekly usage percentage (0.0-1.0)
    let sevenDaySonnet: Double?
    
    /// Opus-specific weekly usage percentage (ignored for now)
    let sevenDayOpus: Double?
    
    /// Extra usage cost information
    let extraUsage: ExtraUsage?
    
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case extraUsage = "extra_usage"
    }
}

/// Extra usage cost data (monthly spend tracking)
struct ExtraUsage: Codable {
    /// Amount spent in dollars
    let spend: Double
    
    /// Spending limit in dollars
    let limit: Double
    
    /// Percentage of limit used (0.0-1.0)
    var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(spend / limit, 1.0)
    }
}
