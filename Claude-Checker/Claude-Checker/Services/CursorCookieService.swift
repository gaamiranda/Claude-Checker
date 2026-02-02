import Foundation

// MARK: - Cursor Cookie Service

/// Service for managing Cursor authentication cookies
/// Users manually paste the Cookie header from their browser
enum CursorCookieService {
    
    // MARK: - Storage Keys
    
    /// UserDefaults key for storing the cookie header
    private static let cookieKey = "cursorCookieHeader"
    
    // MARK: - Public Methods
    
    /// Retrieves the stored cookie header
    /// - Returns: The cookie header string, or nil if not configured
    static func getCookieHeader() -> String? {
        let header = UserDefaults.standard.string(forKey: cookieKey)
        // Return nil if empty string
        guard let header = header, !header.isEmpty else {
            return nil
        }
        return header
    }
    
    /// Saves a cookie header
    /// - Parameter header: The Cookie header value from browser dev tools
    static func saveCookieHeader(_ header: String) {
        // Clean up the header - remove "Cookie: " prefix if present
        var cleanHeader = header.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes users might accidentally include
        let prefixes = ["Cookie:", "cookie:", "Cookie: ", "cookie: "]
        for prefix in prefixes {
            if cleanHeader.hasPrefix(prefix) {
                cleanHeader = String(cleanHeader.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        UserDefaults.standard.set(cleanHeader, forKey: cookieKey)
    }
    
    /// Clears the stored cookie header
    static func clearCookieHeader() {
        UserDefaults.standard.removeObject(forKey: cookieKey)
    }
    
    /// Whether a cookie header is configured
    static var hasCookie: Bool {
        getCookieHeader() != nil
    }
    
    /// Validates that the cookie contains expected Cursor session tokens
    /// - Parameter header: The cookie header to validate
    /// - Returns: true if the header appears to contain valid Cursor cookies
    static func validateCookieHeader(_ header: String) -> Bool {
        let expectedCookies = [
            "WorkosCursorSessionToken",
            "__Secure-next-auth.session-token",
            "next-auth.session-token"
        ]
        
        // Check if at least one expected cookie is present
        return expectedCookies.contains { cookieName in
            header.contains(cookieName)
        }
    }
}
