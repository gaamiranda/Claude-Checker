import Foundation

/// OAuth credentials stored by Claude Code in Keychain or file
struct Credentials: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: String?
    let rateLimitTier: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case rateLimitTier = "rate_limit_tier"
    }
    
    /// Returns the plan tier as a display-friendly string
    var planDisplayName: String {
        guard let tier = rateLimitTier?.lowercased() else {
            return "Unknown"
        }
        
        switch tier {
        case "max":
            return "Max"
        case "pro":
            return "Pro"
        case "team":
            return "Team"
        case "enterprise":
            return "Enterprise"
        default:
            return tier.capitalized
        }
    }
}
