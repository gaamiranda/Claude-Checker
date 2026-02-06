import Foundation

// MARK: - Token Refresh Errors

enum TokenRefreshError: LocalizedError {
    case noRefreshToken
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case invalidGrant
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available. Please run 'claude login' in Terminal."
        case .invalidURL:
            return "Invalid token refresh URL"
        case .networkError(let error):
            return "Network error during token refresh: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from token refresh endpoint"
        case .httpError(let code):
            return "Token refresh failed with HTTP \(code)"
        case .invalidGrant:
            return "Refresh token expired or invalid. Please run 'claude login' in Terminal."
        case .decodingError(let error):
            return "Failed to parse token refresh response: \(error.localizedDescription)"
        }
    }
    
    /// Whether this error indicates the user needs to re-authenticate
    var requiresReauthentication: Bool {
        switch self {
        case .noRefreshToken, .invalidGrant:
            return true
        default:
            return false
        }
    }
}

// MARK: - Token Refresh Response

/// Response from the OAuth token refresh endpoint
private struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

/// Error response from OAuth endpoint
private struct OAuthErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Token Refresh Service

/// Service for refreshing Claude OAuth access tokens
actor TokenRefreshService {
    
    /// Token refresh endpoint (same as Claude CLI uses)
    private let tokenEndpoint = "https://platform.claude.com/v1/oauth/token"
    
    /// OAuth client ID (public, same as Claude CLI)
    /// This is not a secret - it's the same client ID used by Claude Code CLI
    private let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    
    /// Shared URL session
    private let session: URLSession
    
    /// Request timeout
    private let timeout: TimeInterval = 30
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Refreshes an access token using a refresh token
    /// - Parameters:
    ///   - refreshToken: The refresh token from the original credentials
    ///   - existingCredentials: The existing credentials (for preserving scopes, tier, etc.)
    /// - Returns: New OAuth credentials with a fresh access token
    /// - Throws: TokenRefreshError if refresh fails
    func refreshAccessToken(
        refreshToken: String,
        existingCredentials: OAuthCredentials
    ) async throws -> OAuthCredentials {
        
        // Validate refresh token
        let trimmedToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw TokenRefreshError.noRefreshToken
        }
        
        // Build request
        guard let url = URL(string: tokenEndpoint) else {
            throw TokenRefreshError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Build form body
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: trimmedToken),
            URLQueryItem(name: "client_id", value: clientID)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        
        // Make request
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TokenRefreshError.networkError(error)
        }
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenRefreshError.invalidResponse
        }
        
        // Handle errors
        if httpResponse.statusCode != 200 {
            // Try to parse OAuth error
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                if errorResponse.error?.lowercased() == "invalid_grant" {
                    throw TokenRefreshError.invalidGrant
                }
            }
            throw TokenRefreshError.httpError(httpResponse.statusCode)
        }
        
        // Parse successful response
        let tokenResponse: TokenRefreshResponse
        do {
            tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        } catch {
            throw TokenRefreshError.decodingError(error)
        }
        
        // Calculate new expiration time (expiresIn is in seconds)
        let expiresAtMillis = Int64((Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn)) * 1000)
        
        // Create new credentials with refreshed token
        return existingCredentials.withRefreshedToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: expiresAtMillis
        )
    }
}
