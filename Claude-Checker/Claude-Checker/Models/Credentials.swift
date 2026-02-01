import Foundation

/// Root structure of Claude Code credentials in Keychain
struct KeychainCredentials: Codable {
    let claudeAiOauth: OAuthCredentials
}

/// OAuth credentials stored by Claude Code in Keychain
struct OAuthCredentials: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Int64?
    let scopes: [String]?
    let subscriptionType: String?
    let rateLimitTier: String?
    
    /// Returns the plan tier as a display-friendly string
    var planDisplayName: String {
        // First try subscriptionType, then rateLimitTier
        if let subscription = subscriptionType?.lowercased() {
            switch subscription {
            case "max":
                return "Max"
            case "pro":
                return "Pro"
            case "team":
                return "Team"
            case "enterprise":
                return "Enterprise"
            default:
                break
            }
        }
        
        // Parse rateLimitTier (e.g., "default_claude_max_5x" -> "Max")
        if let tier = rateLimitTier?.lowercased() {
            if tier.contains("max") {
                return "Max"
            } else if tier.contains("pro") {
                return "Pro"
            } else if tier.contains("team") {
                return "Team"
            } else if tier.contains("enterprise") {
                return "Enterprise"
            }
        }
        
        return subscriptionType?.capitalized ?? "Unknown"
    }
}

/// Legacy flat structure for file-based credentials (fallback)
struct LegacyCredentials: Codable {
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
    
    /// Convert to OAuthCredentials for unified handling
    func toOAuthCredentials() -> OAuthCredentials {
        OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: nil,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: rateLimitTier
        )
    }
}
