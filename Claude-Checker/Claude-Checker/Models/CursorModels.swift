import Foundation

// MARK: - Usage Summary Response

/// Response from the Cursor usage summary endpoint
/// GET https://www.cursor.com/api/usage-summary
struct CursorUsageSummary: Codable {
    /// Start of the billing cycle (ISO8601)
    let billingCycleStart: String?
    
    /// End of the billing cycle (ISO8601)
    let billingCycleEnd: String?
    
    /// Membership type (e.g., "enterprise", "pro", "hobby")
    let membershipType: String?
    
    /// Limit type
    let limitType: String?
    
    /// Whether usage is unlimited
    let isUnlimited: Bool?
    
    /// Display message for auto-selected model
    let autoModelSelectedDisplayMessage: String?
    
    /// Display message for named model
    let namedModelSelectedDisplayMessage: String?
    
    /// Individual usage data
    let individualUsage: CursorIndividualUsage?
    
    /// Team usage data (for team plans)
    let teamUsage: CursorTeamUsage?
}

/// Individual usage breakdown
struct CursorIndividualUsage: Codable {
    /// Plan usage (included credits)
    let plan: CursorPlanUsage?
    
    /// On-demand usage (pay-as-you-go)
    let onDemand: CursorOnDemandUsage?
}

/// Plan usage data (included credits)
struct CursorPlanUsage: Codable {
    /// Whether plan usage is enabled
    let enabled: Bool?
    
    /// Usage in cents (e.g., 2000 = $20.00)
    let used: Int?
    
    /// Limit in cents (e.g., 2000 = $20.00)
    let limit: Int?
    
    /// Remaining in cents
    let remaining: Int?
    
    /// Breakdown of credits
    let breakdown: CursorPlanBreakdown?
    
    /// Auto usage percentage (0-100)
    let autoPercentUsed: Double?
    
    /// API usage percentage (0-100)
    let apiPercentUsed: Double?
    
    /// Total usage percentage (0-100)
    let totalPercentUsed: Double?
    
    /// Usage as USD
    var usedUSD: Double {
        Double(used ?? 0) / 100.0
    }
    
    /// Limit as USD (uses breakdown.total if available for bonus credits)
    var limitUSD: Double {
        Double(breakdown?.total ?? limit ?? 0) / 100.0
    }
    
    /// Calculated percentage (0.0-1.0)
    var percentage: Double {
        let limitRaw = Double(breakdown?.total ?? limit ?? 0)
        if limitRaw > 0 {
            return min(Double(used ?? 0) / limitRaw, 1.0)
        }
        // Fall back to totalPercentUsed if available
        if let total = totalPercentUsed {
            // API may return 0-1 or 0-100
            return total <= 1 ? total : total / 100.0
        }
        return 0
    }
}

/// Plan credit breakdown
struct CursorPlanBreakdown: Codable {
    /// Included credits in cents
    let included: Int?
    
    /// Bonus credits in cents
    let bonus: Int?
    
    /// Total credits in cents
    let total: Int?
}

/// On-demand usage data
struct CursorOnDemandUsage: Codable {
    /// Whether on-demand is enabled
    let enabled: Bool?
    
    /// Usage in cents
    let used: Int?
    
    /// Limit in cents (nil if unlimited)
    let limit: Int?
    
    /// Remaining in cents (nil if unlimited)
    let remaining: Int?
    
    /// Usage as USD
    var usedUSD: Double {
        Double(used ?? 0) / 100.0
    }
    
    /// Limit as USD (nil if unlimited)
    var limitUSD: Double? {
        guard let limit = limit else { return nil }
        return Double(limit) / 100.0
    }
    
    /// Whether there's a spending limit
    var hasLimit: Bool {
        limit != nil && limit! > 0
    }
}

/// Team usage data
struct CursorTeamUsage: Codable {
    /// Team on-demand usage
    let onDemand: CursorOnDemandUsage?
}

// MARK: - User Info Response

/// Response from the Cursor auth endpoint
/// GET https://www.cursor.com/api/auth/me
struct CursorUserInfo: Codable {
    let email: String?
    let emailVerified: Bool?
    let name: String?
    let sub: String?
    let createdAt: String?
    let updatedAt: String?
    let picture: String?
    
    enum CodingKeys: String, CodingKey {
        case email
        case emailVerified = "email_verified"
        case name
        case sub
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case picture
    }
}

// MARK: - Date Parsing Helper

extension CursorUsageSummary {
    /// Parsed billing cycle end date
    var billingEndDate: Date? {
        guard let dateString = billingCycleEnd else { return nil }
        return parseISO8601Date(dateString)
    }
    
    /// Parsed billing cycle start date
    var billingStartDate: Date? {
        guard let dateString = billingCycleStart else { return nil }
        return parseISO8601Date(dateString)
    }
    
    private func parseISO8601Date(_ dateString: String) -> Date? {
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

// MARK: - Membership Type Display

extension CursorUsageSummary {
    /// Formatted membership type for display
    var membershipDisplayName: String {
        guard let type = membershipType else { return "Unknown" }
        switch type.lowercased() {
        case "enterprise":
            return "Enterprise"
        case "pro":
            return "Pro"
        case "pro_plus", "pro+":
            return "Pro+"
        case "ultra":
            return "Ultra"
        case "hobby":
            return "Hobby"
        case "team":
            return "Team"
        default:
            return type.capitalized
        }
    }
    
    /// Default plan limit in USD based on membership type
    /// - Pro: $20
    /// - Pro+: $60
    /// - Ultra: $200
    /// - Hobby: $0 (free tier)
    var defaultPlanLimitUSD: Double {
        guard let type = membershipType else { return 0 }
        switch type.lowercased() {
        case "pro":
            return 20.0
        case "pro_plus", "pro+":
            return 60.0
        case "ultra":
            return 200.0
        case "enterprise", "team":
            // Enterprise/Team plans vary, use API value or fallback
            return individualUsage?.plan?.limitUSD ?? 0
        default:
            return 0
        }
    }
}
