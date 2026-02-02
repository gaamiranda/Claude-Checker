import Foundation

// MARK: - API Errors

enum CursorAPIError: LocalizedError {
    case noCookieConfigured
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noCookieConfigured:
            return "Cursor cookie not configured. Please paste your cookie from browser."
        case .invalidURL:
            return "Invalid Cursor API URL"
        case .invalidResponse:
            return "Invalid response from Cursor"
        case .unauthorized:
            return "Cookie expired or invalid. Please paste a new cookie from browser."
        case .httpError(let code):
            return "Cursor API error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse Cursor response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Cursor API Client

/// Client for fetching usage data from the Cursor API
actor CursorAPIClient {
    
    /// Base URL for Cursor API
    private let baseURL = "https://www.cursor.com"
    
    /// Shared URL session
    private let session: URLSession
    
    /// Request timeout
    private let timeout: TimeInterval = 15.0
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Fetches usage summary from the Cursor API
    /// - Parameter cookie: Cookie header value from browser
    /// - Returns: Usage summary containing plan and on-demand usage
    /// - Throws: CursorAPIError if the request fails
    func fetchUsageSummary(cookie: String) async throws -> CursorUsageSummary {
        guard let url = URL(string: "\(baseURL)/api/usage-summary") else {
            throw CursorAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CursorAPIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw CursorAPIError.unauthorized
        default:
            throw CursorAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(CursorUsageSummary.self, from: data)
        } catch {
            throw CursorAPIError.decodingError(error)
        }
    }
    
    /// Fetches user info from the Cursor API
    /// - Parameter cookie: Cookie header value from browser
    /// - Returns: User info containing email and name
    /// - Throws: CursorAPIError if the request fails
    func fetchUserInfo(cookie: String) async throws -> CursorUserInfo {
        guard let url = URL(string: "\(baseURL)/api/auth/me") else {
            throw CursorAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CursorAPIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw CursorAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(CursorUserInfo.self, from: data)
        } catch {
            throw CursorAPIError.decodingError(error)
        }
    }
}
