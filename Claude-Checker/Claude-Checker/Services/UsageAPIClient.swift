import Foundation

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case insufficientScope
    case httpError(Int)
    case networkError(Error)
    case decodingError(Error)
    case tokenExpired
    case tokenRefreshFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid or expired token. Please re-authenticate with Claude Code."
        case .insufficientScope:
            return "Token missing required scope. Ensure token has 'user:profile' permission."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .tokenExpired:
            return "Token expired. Attempting to refresh..."
        case .tokenRefreshFailed(let error):
            return "Token refresh failed: \(error.localizedDescription)"
        }
    }
    
    /// Whether this error indicates the user needs to re-authenticate manually
    var requiresReauthentication: Bool {
        switch self {
        case .unauthorized, .insufficientScope:
            return true
        case .tokenRefreshFailed(let error):
            if let refreshError = error as? TokenRefreshError {
                return refreshError.requiresReauthentication
            }
            return false
        default:
            return false
        }
    }
}

// MARK: - Usage API Client

/// Client for fetching usage data from the Anthropic OAuth API with automatic token refresh
actor UsageAPIClient {
    /// Base URL for the usage endpoint
    private let baseURL = "https://api.anthropic.com/api/oauth/usage"
    
    /// Required beta header value
    private let betaHeader = "oauth-2025-04-20"
    
    /// Shared URL session
    private let session: URLSession
    
    /// Token refresh service
    private let tokenRefreshService = TokenRefreshService()
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Fetches usage data from the Anthropic API, automatically refreshing token if needed
    /// - Parameter credentials: OAuth credentials (may be expired, will be refreshed)
    /// - Returns: Tuple of (UsageResponse, possibly refreshed credentials)
    /// - Throws: APIError if the request fails
    func fetchUsage(credentials: OAuthCredentials) async throws -> (UsageResponse, OAuthCredentials) {
        var activeCredentials = credentials
        
        // Check if token is expired or will expire soon (within 5 minutes)
        if activeCredentials.willExpireSoon(within: 300) {
            // Try to refresh
            activeCredentials = try await refreshTokenIfPossible(activeCredentials)
        }
        
        // Make the API request
        do {
            let usage = try await makeUsageRequest(token: activeCredentials.accessToken)
            return (usage, activeCredentials)
        } catch let error as APIError {
            // If we get unauthorized, try refreshing once more
            if case .unauthorized = error, activeCredentials.canRefresh {
                activeCredentials = try await refreshTokenIfPossible(activeCredentials)
                let usage = try await makeUsageRequest(token: activeCredentials.accessToken)
                return (usage, activeCredentials)
            }
            throw error
        }
    }
    
    /// Legacy method for compatibility - fetches using just a token string
    /// - Parameter token: OAuth access token
    /// - Returns: Usage response
    /// - Throws: APIError if the request fails
    func fetchUsage(token: String) async throws -> UsageResponse {
        try await makeUsageRequest(token: token)
    }
    
    // MARK: - Private Methods
    
    /// Refreshes the token if a refresh token is available
    private func refreshTokenIfPossible(_ credentials: OAuthCredentials) async throws -> OAuthCredentials {
        guard let refreshToken = credentials.refreshToken,
              !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // No refresh token available
            if credentials.isExpired {
                throw APIError.tokenRefreshFailed(TokenRefreshError.noRefreshToken)
            }
            // Token not expired yet, use as-is
            return credentials
        }
        
        do {
            let refreshed = try await tokenRefreshService.refreshAccessToken(
                refreshToken: refreshToken,
                existingCredentials: credentials
            )
            
            // Cache the refreshed credentials
            KeychainService.cacheRefreshedCredentials(refreshed)
            
            return refreshed
        } catch {
            // If refresh fails and token is expired, we can't continue
            if credentials.isExpired {
                throw APIError.tokenRefreshFailed(error)
            }
            // Token not expired yet, try using it anyway
            return credentials
        }
    }
    
    /// Makes the actual API request
    private func makeUsageRequest(token: String) async throws -> UsageResponse {
        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.insufficientScope
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(UsageResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
