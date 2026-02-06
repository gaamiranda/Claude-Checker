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
    
    // MARK: - Expiration Checking
    
    /// The expiration date parsed from expiresAt (milliseconds since epoch)
    var expirationDate: Date? {
        guard let expiresAt = expiresAt else { return nil }
        // expiresAt is in milliseconds, convert to seconds
        return Date(timeIntervalSince1970: Double(expiresAt) / 1000.0)
    }
    
    /// Whether the access token is expired
    var isExpired: Bool {
        guard let expDate = expirationDate else {
            // If no expiration date, assume expired to be safe
            return true
        }
        return Date() >= expDate
    }
    
    /// Whether the access token will expire within the given time interval
    /// - Parameter interval: Time interval in seconds (default 5 minutes)
    func willExpireSoon(within interval: TimeInterval = 300) -> Bool {
        guard let expDate = expirationDate else {
            return true
        }
        return Date().addingTimeInterval(interval) >= expDate
    }
    
    /// Time interval until token expires (negative if already expired)
    var expiresIn: TimeInterval? {
        guard let expDate = expirationDate else { return nil }
        return expDate.timeIntervalSinceNow
    }
    
    /// Whether a refresh token is available
    var canRefresh: Bool {
        guard let refreshToken = refreshToken else { return false }
        return !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Plan Display
    
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
    
    // MARK: - Creating Updated Credentials
    
    /// Creates a new OAuthCredentials with an updated access token and expiration
    func withRefreshedToken(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Int64
    ) -> OAuthCredentials {
        OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken ?? self.refreshToken,
            expiresAt: expiresAt,
            scopes: self.scopes,
            subscriptionType: self.subscriptionType,
            rateLimitTier: self.rateLimitTier
        )
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
        // Try to parse expiresAt as a number (milliseconds)
        var expiresAtInt: Int64? = nil
        if let expiresAtStr = expiresAt {
            expiresAtInt = Int64(expiresAtStr)
        }
        
        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAtInt,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: rateLimitTier
        )
    }
}
