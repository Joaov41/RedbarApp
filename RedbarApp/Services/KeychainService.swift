import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = "RedbarApp"
    
    private init() {}
    
    enum KeychainError: Error {
        case noData
        case unhandledError(status: OSStatus)
    }
    
    func save(key: String, value: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func get(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecItemNotFound {
            throw KeychainError.noData
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = dataTypeRef as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.noData
        }
        
        return string
    }
    
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func exists(key: String) -> Bool {
        do {
            _ = try get(key: key)
            return true
        } catch {
            return false
        }
    }
}

extension KeychainService {
    private enum Keys {
        static let openAIAPIKey = "openai_api_key"
        static let geminiAPIKey = "gemini_api_key"
        static let redditClientId = "reddit_client_id"
        static let redditClientSecret = "reddit_client_secret"
        static let redditAccessToken = "reddit_access_token"
        static let redditRefreshToken = "reddit_refresh_token"
        static let redditUsername = "reddit_username"
    }
    
    var openAIAPIKey: String? {
        get {
            try? get(key: Keys.openAIAPIKey)
        }
        set {
            if let newValue = newValue {
                try? save(key: Keys.openAIAPIKey, value: newValue)
            } else {
                try? delete(key: Keys.openAIAPIKey)
            }
        }
    }
    
    var geminiAPIKey: String? {
        get {
            try? get(key: Keys.geminiAPIKey)
        }
        set {
            if let newValue = newValue {
                try? save(key: Keys.geminiAPIKey, value: newValue)
            } else {
                try? delete(key: Keys.geminiAPIKey)
            }
        }
    }
    
    var redditClientId: String? {
        get {
            try? get(key: Keys.redditClientId)
        }
        set {
            if let newValue = newValue {
                try? save(key: Keys.redditClientId, value: newValue)
            } else {
                try? delete(key: Keys.redditClientId)
            }
        }
    }
    
    var redditClientSecret: String? {
        get {
            try? get(key: Keys.redditClientSecret)
        }
        set {
            if let newValue = newValue {
                try? save(key: Keys.redditClientSecret, value: newValue)
            } else {
                try? delete(key: Keys.redditClientSecret)
            }
        }
    }
    
    var redditAccessToken: String? {
        get {
            try? get(key: Keys.redditAccessToken)
        }
        set {
            if let newValue = newValue {
                try? save(key: Keys.redditAccessToken, value: newValue)
            } else {
                try? delete(key: Keys.redditAccessToken)
            }
        }
    }
    
    var redditRefreshToken: String? {
        get {
            try? get(key: Keys.redditRefreshToken)
        }
        set {
            if let newValue = newValue {
                try? save(key: Keys.redditRefreshToken, value: newValue)
            } else {
                try? delete(key: Keys.redditRefreshToken)
            }
        }
    }
    
    var redditUsername: String? {
        get {
            try? get(key: Keys.redditUsername)
        }
        set {
            if let newValue = newValue {
                try? save(key: Keys.redditUsername, value: newValue)
            } else {
                try? delete(key: Keys.redditUsername)
            }
        }
    }
}