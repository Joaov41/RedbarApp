import Foundation
import AuthenticationServices

class RedditAuthManager: NSObject, ObservableObject {
    static let shared = RedditAuthManager()
    
    @Published var isAuthenticated = false
    @Published var username: String?
    
    private let keychain = KeychainService.shared
    private var authSession: ASWebAuthenticationSession?
    
    // OAuth Configuration
    private let redirectURI = "redapp://auth"
    private let authorizationURL = "https://www.reddit.com/api/v1/authorize"
    private let tokenURL = "https://www.reddit.com/api/v1/access_token"
    private let scopes = "identity submit read"
    
    private var clientId: String? {
        keychain.redditClientId
    }
    
    private var clientSecret: String? {
        keychain.redditClientSecret
    }
    
    var accessToken: String? {
        get { keychain.redditAccessToken }
        set { 
            keychain.redditAccessToken = newValue
            isAuthenticated = newValue != nil
        }
    }
    
    private var refreshToken: String? {
        get { keychain.redditRefreshToken }
        set { keychain.redditRefreshToken = newValue }
    }
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        isAuthenticated = accessToken != nil
        username = keychain.redditUsername
    }
    
    func setRedditCredentials(clientId: String, clientSecret: String?) {
        keychain.redditClientId = clientId
        keychain.redditClientSecret = clientSecret
    }
    
    func hasStoredCredentials() -> Bool {
        return clientId != nil
    }
    
    func authenticate() {
        guard let clientId = clientId else {
            print("❌ Reddit Auth Error: No Reddit client ID configured")
            return
        }
        
        print("🔐 Starting Reddit authentication...")
        print("📋 Client ID: \(String(clientId.prefix(8)))...")
        
        // Generate random state for security
        let state = UUID().uuidString
        
        // Build authorization URL
        var components = URLComponents(string: authorizationURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "duration", value: "permanent"),
            URLQueryItem(name: "scope", value: scopes)
        ]
        
        guard let authURL = components.url else {
            print("❌ Reddit Auth Error: Failed to build authorization URL")
            return
        }
        
        print("🌐 Authorization URL: \(authURL.absoluteString)")
        print("↩️ Redirect URI: \(redirectURI)")
        
        // Create and start authentication session
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "redapp") { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Reddit Auth Error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Error Code: \(nsError.code)")
                    print("   Error Domain: \(nsError.domain)")
                    print("   Error Info: \(nsError.userInfo)")
                }
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("❌ Reddit Auth Error: No callback URL received")
                return
            }
            
            print("✅ Received callback URL: \(callbackURL.absoluteString)")
            
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                print("❌ Reddit Auth Error: Failed to parse callback URL")
                return
            }
            
            if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                print("❌ Reddit Auth Error: \(error)")
                if let errorDescription = components.queryItems?.first(where: { $0.name == "error_description" })?.value {
                    print("   Description: \(errorDescription)")
                }
                return
            }
            
            guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                print("❌ Reddit Auth Error: No authorization code in callback")
                print("   Query items: \(components.queryItems?.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", ") ?? "none")")
                return
            }
            
            print("✅ Got authorization code: \(String(code.prefix(10)))...")
            
            // Exchange code for access token
            Task {
                await self.exchangeCodeForToken(code: code)
            }
        }
        
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }
    
    private func exchangeCodeForToken(code: String) async {
        guard let clientId = clientId else {
            print("❌ Token Exchange Error: No client ID")
            return
        }
        
        print("🔄 Exchanging authorization code for access token...")
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        
        // Basic auth header
        let credentials = "\(clientId):\(clientSecret ?? "")"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("RedbarApp/1.0", forHTTPHeaderField: "User-Agent")
        
        // Body parameters
        let parameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI
        ]
        
        let body = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        print("📤 Token Request URL: \(tokenURL)")
        print("📤 Request Body: \(body)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Response Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Token Exchange Error Response: \(responseString)")
                    }
                }
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📥 Token Response: \(json.keys.joined(separator: ", "))")
                
                if let error = json["error"] as? String {
                    print("❌ Reddit API Error: \(error)")
                    if let errorDescription = json["error_description"] as? String {
                        print("   Description: \(errorDescription)")
                    }
                    return
                }
                
                if let accessToken = json["access_token"] as? String,
                   let refreshToken = json["refresh_token"] as? String {
                    
                    print("✅ Successfully obtained access token")
                    
                    await MainActor.run {
                        self.accessToken = accessToken
                        self.refreshToken = refreshToken
                        self.isAuthenticated = true
                    }
                    
                    // Fetch user info
                    await fetchUserInfo()
                } else {
                    print("❌ Token Exchange Error: Missing access_token or refresh_token in response")
                }
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Token Exchange Error: Invalid JSON response: \(responseString)")
                }
            }
        } catch {
            print("❌ Token Exchange Network Error: \(error.localizedDescription)")
        }
    }
    
    func refreshTokenIfNeeded() async {
        guard let refreshToken = refreshToken,
              let clientId = clientId else { return }
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        
        // Basic auth header
        let credentials = "\(clientId):\(clientSecret ?? "")"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body parameters
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let body = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newAccessToken = json["access_token"] as? String {
                await MainActor.run {
                    self.accessToken = newAccessToken
                }
            }
        } catch {
            print("Token refresh error: \(error)")
            // If refresh fails, user needs to re-authenticate
            await MainActor.run {
                self.logout()
            }
        }
    }
    
    private func fetchUserInfo() async {
        guard let accessToken = accessToken else { return }
        
        var request = URLRequest(url: URL(string: "https://oauth.reddit.com/api/v1/me")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("RedbarApp/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let username = json["name"] as? String {
                await MainActor.run {
                    self.username = username
                    self.keychain.redditUsername = username
                }
            }
        } catch {
            print("Failed to fetch user info: \(error)")
        }
    }
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        username = nil
        keychain.redditUsername = nil
        isAuthenticated = false
    }
    
    func getStoredClientId() -> String? {
        return clientId
    }
    
    func getStoredClientSecret() -> String? {
        return clientSecret
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension RedditAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
    }
}

// MARK: - Error Types
enum RedditAuthError: Error {
    case noAccessToken
    case invalidResponse
    case networkError(Error)
}