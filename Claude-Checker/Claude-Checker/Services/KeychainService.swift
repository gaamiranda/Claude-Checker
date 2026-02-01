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
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No credentials found. Please log in with Claude Code first."
        case .invalidFormat(let error):
            return "Invalid credential format: \(error.localizedDescription)"
        case .fileReadError(let error):
            return "Failed to read credentials file: \(error.localizedDescription)"
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
    
    /// Retrieves credentials from Keychain or fallback file
    /// - Returns: Parsed OAuth credentials
    /// - Throws: CredentialError if credentials cannot be found or parsed
    static func getCredentials() throws -> OAuthCredentials {
        // Try Keychain first
        if let data = readFromKeychain() {
            do {
                let decoder = JSONDecoder()
                // Try parsing as the nested KeychainCredentials structure
                let keychainCreds = try decoder.decode(KeychainCredentials.self, from: data)
                return keychainCreds.claudeAiOauth
            } catch {
                throw CredentialError.invalidFormat(error)
            }
        }
        
        // Fallback to file
        return try readFromFile()
    }
    
    // MARK: - Private Methods
    
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
            return keychainCreds.claudeAiOauth
        } catch {
            // Fall back to legacy flat structure
            do {
                let legacyCreds = try decoder.decode(LegacyCredentials.self, from: data)
                return legacyCreds.toOAuthCredentials()
            } catch {
                throw CredentialError.invalidFormat(error)
            }
        }
    }
}
