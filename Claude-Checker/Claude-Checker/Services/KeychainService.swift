import Foundation
import Security

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Credentials not found in Keychain"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Invalid credential data"
        case .decodingFailed(let error):
            return "Failed to decode credentials: \(error.localizedDescription)"
        }
    }
}

// MARK: - Credential Errors

enum CredentialError: LocalizedError {
    case notFound
    case invalidFormat(Error)
    case fileReadError(Error)
    case tokenExpired
    case refreshFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No credentials found. Please log in with Claude Code first."
        case .invalidFormat(let error):
            return "Invalid credential format: \(error.localizedDescription)"
        case .fileReadError(let error):
            return "Failed to read credentials file: \(error.localizedDescription)"
        case .tokenExpired:
            return "Token expired. Please run 'claude login' in Terminal."
        case .refreshFailed(let error):
            return "Token refresh failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Keychain Service

/// Service for reading Claude Code OAuth credentials from Keychain or fallback file
enum KeychainService {
    /// Keychain service name used by Claude Code
    static let serviceName = "Claude Code-credentials"
    
    /// Fallback file path for credentials
    static let fallbackPath = "~/.claude/.credentials.json"
    
    /// UserDefaults key for cached credentials
    private static let cachedCredentialsKey = "cachedClaudeCredentials"
    
    /// In-memory cache for credentials (thread-safe via actor isolation in callers)
    private static var memoryCache: OAuthCredentials?
    private static var memoryCacheTimestamp: Date?
    
    /// Memory cache validity duration (30 minutes)
    private static let memoryCacheValidity: TimeInterval = 1800
    
    // MARK: - Public Methods
    
    /// Retrieves credentials from cache, Keychain, or fallback file
    /// - Returns: Parsed OAuth credentials
    /// - Throws: CredentialError if credentials cannot be found or parsed
    static func getCredentials() throws -> OAuthCredentials {
        // 1. Check memory cache first (for refreshed tokens)
        if let cached = getFromMemoryCache() {
            return cached
        }
        
        // 2. Check UserDefaults cache (persisted refreshed tokens)
        if let cached = getFromUserDefaultsCache() {
            // Store in memory for faster access
            setMemoryCache(cached)
            return cached
        }
        
        // 3. Try Keychain
        if let data = readFromKeychain() {
            do {
                let decoder = JSONDecoder()
                let keychainCreds = try decoder.decode(KeychainCredentials.self, from: data)
                let credentials = keychainCreds.claudeAiOauth
                
                // Cache in memory
                setMemoryCache(credentials)
                
                return credentials
            } catch {
                throw CredentialError.invalidFormat(error)
            }
        }
        
        // 4. Fallback to file
        return try readFromFile()
    }
    
    /// Caches refreshed credentials (in memory and UserDefaults)
    /// - Parameter credentials: The refreshed credentials to cache
    static func cacheRefreshedCredentials(_ credentials: OAuthCredentials) {
        // Store in memory
        setMemoryCache(credentials)
        
        // Store in UserDefaults for persistence across app restarts
        saveToUserDefaultsCache(credentials)
    }
    
    /// Clears the credential cache (call when user logs out or on auth errors)
    static func clearCache() {
        memoryCache = nil
        memoryCacheTimestamp = nil
        UserDefaults.standard.removeObject(forKey: cachedCredentialsKey)
    }
    
    /// Invalidates the cache if the source credentials file has changed
    /// This allows picking up new credentials after `claude login`
    static func invalidateCacheIfNeeded() {
        // Check if the credentials file has been modified
        let expandedPath = NSString(string: fallbackPath).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)
        
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return
        }
        
        // If file was modified after our cache was created, invalidate cache
        if let cacheTime = memoryCacheTimestamp, modDate > cacheTime {
            clearCache()
        }
    }
    
    // MARK: - Memory Cache
    
    private static func getFromMemoryCache() -> OAuthCredentials? {
        guard let cached = memoryCache,
              let timestamp = memoryCacheTimestamp,
              Date().timeIntervalSince(timestamp) < memoryCacheValidity else {
            return nil
        }
        
        // Don't return expired credentials from cache
        // (let the caller handle refresh)
        return cached
    }
    
    private static func setMemoryCache(_ credentials: OAuthCredentials) {
        memoryCache = credentials
        memoryCacheTimestamp = Date()
    }
    
    // MARK: - UserDefaults Cache
    
    /// Cached credentials structure for UserDefaults
    private struct CachedCredentials: Codable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Int64?
        let scopes: [String]?
        let subscriptionType: String?
        let rateLimitTier: String?
        let cachedAt: Date
        
        func toOAuthCredentials() -> OAuthCredentials {
            OAuthCredentials(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt,
                scopes: scopes,
                subscriptionType: subscriptionType,
                rateLimitTier: rateLimitTier
            )
        }
        
        static func from(_ credentials: OAuthCredentials) -> CachedCredentials {
            CachedCredentials(
                accessToken: credentials.accessToken,
                refreshToken: credentials.refreshToken,
                expiresAt: credentials.expiresAt,
                scopes: credentials.scopes,
                subscriptionType: credentials.subscriptionType,
                rateLimitTier: credentials.rateLimitTier,
                cachedAt: Date()
            )
        }
    }
    
    private static func getFromUserDefaultsCache() -> OAuthCredentials? {
        guard let data = UserDefaults.standard.data(forKey: cachedCredentialsKey) else {
            return nil
        }
        
        guard let cached = try? JSONDecoder().decode(CachedCredentials.self, from: data) else {
            // Invalid cache, clear it
            UserDefaults.standard.removeObject(forKey: cachedCredentialsKey)
            return nil
        }
        
        let credentials = cached.toOAuthCredentials()
        
        // Don't return if the cached token is expired AND has no refresh token
        // (if it has a refresh token, let the caller handle refresh)
        if credentials.isExpired && !credentials.canRefresh {
            return nil
        }
        
        return credentials
    }
    
    private static func saveToUserDefaultsCache(_ credentials: OAuthCredentials) {
        let cached = CachedCredentials.from(credentials)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cachedCredentialsKey)
        }
    }
    
    // MARK: - Keychain Access
    
    /// Reads credential data from Keychain
    /// - Returns: Raw JSON data if found, nil otherwise
    private static func readFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                print("Keychain read error: \(status)")
            }
            return nil
        }
        
        return result as? Data
    }
    
    // MARK: - File Access
    
    /// Reads credentials from the fallback JSON file
    /// - Returns: Parsed OAuth credentials
    /// - Throws: CredentialError if file cannot be read or parsed
    private static func readFromFile() throws -> OAuthCredentials {
        let expandedPath = NSString(string: fallbackPath).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)
        
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw CredentialError.notFound
        }
        
        let decoder = JSONDecoder()
        
        // Try parsing as KeychainCredentials first (nested structure)
        do {
            let keychainCreds = try decoder.decode(KeychainCredentials.self, from: data)
            let credentials = keychainCreds.claudeAiOauth
            setMemoryCache(credentials)
            return credentials
        } catch {
            // Fall back to legacy flat structure
            do {
                let legacyCreds = try decoder.decode(LegacyCredentials.self, from: data)
                let credentials = legacyCreds.toOAuthCredentials()
                setMemoryCache(credentials)
                return credentials
            } catch {
                throw CredentialError.invalidFormat(error)
            }
        }
    }
}
