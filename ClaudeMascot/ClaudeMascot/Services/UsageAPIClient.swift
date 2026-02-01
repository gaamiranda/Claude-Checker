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
        }
    }
}

// MARK: - Usage API Client

/// Client for fetching usage data from the Anthropic OAuth API
actor UsageAPIClient {
    /// Base URL for the usage endpoint
    private let baseURL = "https://api.anthropic.com/api/oauth/usage"
    
    /// Required beta header value
    private let betaHeader = "oauth-2025-04-20"
    
    /// Shared URL session
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Fetches usage data from the Anthropic API
    /// - Parameter token: OAuth access token with user:profile scope
    /// - Returns: Usage response containing session and weekly percentages
    /// - Throws: APIError if the request fails
    func fetchUsage(token: String) async throws -> UsageResponse {
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
