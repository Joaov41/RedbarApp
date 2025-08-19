import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var openAIAPIKey: String = ""
    @State private var geminiAPIKey: String = ""
    @State private var openAIKeyStatus: APIKeyStatus = .notSet
    @State private var geminiKeyStatus: APIKeyStatus = .notSet
    @State private var redditClientId: String = ""
    @State private var redditClientSecret: String = ""
    @State private var redditKeyStatus: APIKeyStatus = .notSet
    @StateObject private var authManager = RedditAuthManager.shared
    @AppStorage("glassVariant") private var glassVariant: Int = 11
    
    private let keychain = KeychainService.shared
    
    enum APIKeyStatus {
        case notSet
        case valid
        case invalid
        case testing
        
        var color: Color {
            switch self {
            case .notSet: return .secondary
            case .valid: return .green
            case .invalid: return .red
            case .testing: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .notSet: return "key"
            case .valid: return "checkmark.circle.fill"
            case .invalid: return "xmark.circle.fill"
            case .testing: return "clock"
            }
        }
        
        var text: String {
            switch self {
            case .notSet: return "Not Set"
            case .valid: return "Valid"
            case .invalid: return "Invalid"
            case .testing: return "Testing..."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 0) {
                HStack {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // API Settings Header
                    VStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        Text("API Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Configure your API keys for AI services")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    Divider()
                    
                    // OpenAI API Key Section
                    LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                        VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("OpenAI API Key", systemImage: "brain.head.profile")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: openAIKeyStatus.icon)
                                Text(openAIKeyStatus.text)
                                    .font(.caption)
                            }
                            .foregroundColor(openAIKeyStatus.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Enter OpenAI API Key (sk-...)", text: $openAIAPIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: openAIAPIKey) { _ in
                                    if !openAIAPIKey.isEmpty {
                                        openAIKeyStatus = .notSet
                                    }
                                }
                            
                            HStack {
                                Button("Save") {
                                    saveOpenAIKey()
                                }
                                .disabled(openAIAPIKey.isEmpty)
                                .buttonStyle(.borderedProminent)
                                
                                if keychain.exists(key: "openai_api_key") {
                                    Button("Clear") {
                                        clearOpenAIKey()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Spacer()
                                
                                Button("Test") {
                                    testOpenAIKey()
                                }
                                .disabled(openAIAPIKey.isEmpty && !keychain.exists(key: "openai_api_key"))
                                .buttonStyle(.bordered)
                            }
                            
                            Text("Required for text-to-speech functionality. Get your key from OpenAI Platform.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                    
                    // Gemini API Key Section
                    LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                        VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Gemini API Key", systemImage: "sparkles")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: geminiKeyStatus.icon)
                                Text(geminiKeyStatus.text)
                                    .font(.caption)
                            }
                            .foregroundColor(geminiKeyStatus.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Enter Gemini API Key (AIza...)", text: $geminiAPIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: geminiAPIKey) { _ in
                                    if !geminiAPIKey.isEmpty {
                                        geminiKeyStatus = .notSet
                                    }
                                }
                            
                            HStack {
                                Button("Save") {
                                    saveGeminiKey()
                                }
                                .disabled(geminiAPIKey.isEmpty)
                                .buttonStyle(.borderedProminent)
                                
                                if keychain.exists(key: "gemini_api_key") {
                                    Button("Clear") {
                                        clearGeminiKey()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Spacer()
                                
                                Button("Test") {
                                    testGeminiKey()
                                }
                                .disabled(geminiAPIKey.isEmpty && !keychain.exists(key: "gemini_api_key"))
                                .buttonStyle(.bordered)
                            }
                            
                            Text("Optional for future AI features. Get your key from Google AI Studio.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                // Reddit Authentication Section
                LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Reddit Authentication", systemImage: "person.crop.circle")
                                .font(.headline)
                            Spacer()
                            if authManager.isAuthenticated {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Connected as \(authManager.username ?? "Unknown")")
                                        .font(.caption)
                                }
                                .foregroundColor(.green)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: redditKeyStatus.icon)
                                    Text(redditKeyStatus.text)
                                        .font(.caption)
                                }
                                .foregroundColor(redditKeyStatus.color)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Reddit App Client ID", text: $redditClientId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: redditClientId) { _ in
                                    if !redditClientId.isEmpty {
                                        redditKeyStatus = .notSet
                                    }
                                }
                            
                            SecureField("Reddit App Client Secret (optional)", text: $redditClientSecret)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            HStack {
                                if !authManager.isAuthenticated {
                                    Button("Save Credentials") {
                                        saveRedditCredentials()
                                    }
                                    .disabled(redditClientId.isEmpty)
                                    .buttonStyle(.borderedProminent)
                                    
                                    if keychain.exists(key: "reddit_client_id") {
                                        Button("Clear") {
                                            clearRedditCredentials()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Login with Reddit") {
                                        authenticateWithReddit()
                                    }
                                    .disabled(!authManager.hasStoredCredentials() && redditClientId.isEmpty)
                                    .buttonStyle(.bordered)
                                } else {
                                    Button("Logout") {
                                        authManager.logout()
                                        redditKeyStatus = .notSet
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Spacer()
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create a Reddit app at reddit.com/prefs/apps")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("• App type: 'installed app'")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("• Redirect URI: redapp://auth")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("• Client Secret: leave empty for installed apps")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("• Make sure the redirect URI matches EXACTLY")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                
                // Glass Effect Settings Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Glass Effect Style", systemImage: "sparkles.rectangle.stack")
                            .font(.headline)
                        Spacer()
                    }
                    
                    // Preview of current glass variant
                    LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 12) {
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                            Text("Variant \(glassVariant)")
                                .font(.title3.bold())
                            Text("Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Glass Variant")
                                .font(.subheadline)
                            Spacer()
                            Text("\(glassVariant)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: Binding(
                            get: { Double(glassVariant) },
                            set: { glassVariant = Int($0) }
                        ), in: 0...19, step: 1)
                        
                        HStack {
                            Text("More Visible")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("More Subtle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Variants 0-5 tend to be more visible, while 10-19 are more subtle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 500, height: 750)
        .onAppear {
            loadExistingKeys()
        }
    }
    
    private func loadExistingKeys() {
        if let existingOpenAIKey = keychain.openAIAPIKey {
            openAIAPIKey = existingOpenAIKey
            openAIKeyStatus = .valid
            print("DEBUG: Loaded OpenAI key starting with: \(String(existingOpenAIKey.prefix(8)))")
        }
        
        if let existingGeminiKey = keychain.geminiAPIKey {
            geminiAPIKey = existingGeminiKey
            geminiKeyStatus = .valid
            print("DEBUG: Loaded Gemini key starting with: \(String(existingGeminiKey.prefix(8)))")
        }
        
        if let existingRedditClientId = keychain.redditClientId {
            redditClientId = existingRedditClientId
            redditKeyStatus = .valid
            print("DEBUG: Loaded Reddit Client ID: \(String(existingRedditClientId.prefix(8)))")
        }
        
        if let existingRedditClientSecret = keychain.redditClientSecret {
            redditClientSecret = existingRedditClientSecret
        }
    }
    
    private func saveOpenAIKey() {
        guard !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        keychain.openAIAPIKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        openAIKeyStatus = .valid
    }
    
    private func saveGeminiKey() {
        let trimmedKey = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return
        }
        
        keychain.geminiAPIKey = trimmedKey
        geminiKeyStatus = .valid
    }
    
    private func clearOpenAIKey() {
        keychain.openAIAPIKey = nil
        openAIAPIKey = ""
        openAIKeyStatus = .notSet
    }
    
    private func clearGeminiKey() {
        keychain.geminiAPIKey = nil
        geminiAPIKey = ""
        geminiKeyStatus = .notSet
    }
    
    private func testOpenAIKey() {
        let keyToTest = openAIAPIKey.isEmpty ? (keychain.openAIAPIKey ?? "") : openAIAPIKey
        
        guard !keyToTest.isEmpty else {
            openAIKeyStatus = .invalid
            return
        }
        
        openAIKeyStatus = .testing
        
        Task {
            await MainActor.run {
                if validateOpenAIKeyFormat(keyToTest) {
                    openAIKeyStatus = .valid
                } else {
                    openAIKeyStatus = .invalid
                }
            }
        }
    }
    
    private func testGeminiKey() {
        let keyToTest = geminiAPIKey.isEmpty ? (keychain.geminiAPIKey ?? "") : geminiAPIKey
        
        guard !keyToTest.isEmpty else {
            geminiKeyStatus = .invalid
            return
        }
        
        geminiKeyStatus = .testing
        
        Task {
            await MainActor.run {
                if validateGeminiKeyFormat(keyToTest) {
                    geminiKeyStatus = .valid
                } else {
                    geminiKeyStatus = .invalid
                }
            }
        }
    }
    
    private func validateOpenAIKeyFormat(_ key: String) -> Bool {
        return key.hasPrefix("sk-") || key.hasPrefix("sk-proj-")
    }
    
    private func validateGeminiKeyFormat(_ key: String) -> Bool {
        // Gemini keys should start with "AIza" and be at least 30 characters
        return key.hasPrefix("AIza") && key.count >= 30
    }
    
    private func saveRedditCredentials() {
        guard !redditClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let trimmedClientId = redditClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientSecret = redditClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate client ID format (should be around 14-22 characters, alphanumeric with dashes/underscores)
        if trimmedClientId.count < 10 || trimmedClientId.count > 30 {
            print("❌ Invalid Reddit Client ID length: \(trimmedClientId.count)")
            redditKeyStatus = .invalid
            return
        }
        
        // Check if client ID contains only valid characters
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if trimmedClientId.rangeOfCharacter(from: validCharacterSet.inverted) != nil {
            print("❌ Invalid characters in Reddit Client ID")
            redditKeyStatus = .invalid
            return
        }
        
        keychain.redditClientId = trimmedClientId
        keychain.redditClientSecret = trimmedClientSecret.isEmpty ? nil : trimmedClientSecret
        
        authManager.setRedditCredentials(clientId: trimmedClientId, clientSecret: trimmedClientSecret.isEmpty ? nil : trimmedClientSecret)
        redditKeyStatus = .valid
        
        print("✅ Reddit credentials saved successfully")
        print("   Client ID: \(String(trimmedClientId.prefix(8)))...")
        print("   Client Secret: \(trimmedClientSecret.isEmpty ? "Not provided" : "Provided")")
    }
    
    private func clearRedditCredentials() {
        keychain.redditClientId = nil
        keychain.redditClientSecret = nil
        redditClientId = ""
        redditClientSecret = ""
        redditKeyStatus = .notSet
        authManager.logout()
    }
    
    private func authenticateWithReddit() {
        authManager.authenticate()
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}