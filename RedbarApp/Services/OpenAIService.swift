import Foundation
import AVFoundation
import SwiftUI

enum OpenAIVoice: String, CaseIterable {
    case alloy = "alloy"
    case echo = "echo"
    case fable = "fable"
    case onyx = "onyx"
    case nova = "nova"
    case shimmer = "shimmer"
    
    var displayName: String {
        switch self {
        case .alloy: return "Alloy (Balanced)"
        case .echo: return "Echo (Warm)"
        case .fable: return "Fable (Expressive)"
        case .onyx: return "Onyx (Deep)"
        case .nova: return "Nova (Energetic)"
        case .shimmer: return "Shimmer (Clear)"
        }
    }
}

actor OpenAIService {
    static let shared = OpenAIService()
    private let keychain = KeychainService.shared
    private let cache = AudioCache.shared
    private let chunkManager = TTSChunkManager()
    private var maxConcurrentRequests = 2 // Start conservative, will adapt
    private let minConcurrentRequests = 1
    private let maxConcurrentRequestsLimit = 4
    
    // Network performance tracking for concurrent limits
    private var concurrentRequestTimes: [TimeInterval] = []
    private let maxConcurrentTimeHistory = 3
    
    @AppStorage("selectedVoice") private var selectedVoice: String = OpenAIVoice.alloy.rawValue
    
    private init() { }
    
    var currentVoice: OpenAIVoice {
        get {
            OpenAIVoice(rawValue: selectedVoice) ?? .alloy
        }
        set {
            selectedVoice = newValue.rawValue
        }
    }
    
    func synthesizeSpeech(text: String, voice: String? = nil, progressHandler: ((Double) -> Void)? = nil, onFirstChunkReady: ((AVAudioPlayer) -> Void)? = nil) async throws -> AVAudioPlayer {
        guard let apiKey = keychain.openAIAPIKey, !apiKey.isEmpty else {
            print("OpenAIService (TTS) - Error: API key is missing.")
            throw NSError(domain: "OpenAIService.synthesizeSpeech", code: 0, userInfo: [NSLocalizedDescriptionKey: "API key is missing. Please set your OpenAI API key in Settings."])
        }
        
        let voiceToUse = voice ?? selectedVoice
        chunkManager.prepareText(text)
        
        var audioData = Data()
        var processedChunks = 0
        let totalChunks = chunkManager.totalChunks
        var firstChunkSent = false
        
        // Process chunks concurrently with a limit
        while chunkManager.hasMoreChunks {
            let chunks = await withTaskGroup(of: (Int, Data?).self) { group -> [(Int, Data?)] in
                var results: [(Int, Data?)] = []
                var activeRequests = 0
                
                let batchSize = maxConcurrentRequests
                
                while activeRequests < batchSize && chunkManager.hasMoreChunks {
                    if let chunk = chunkManager.nextChunk() {
                        group.addTask {
                            let index = processedChunks + activeRequests
                            let cacheKey = self.chunkManager.getCacheKey(for: chunk, voice: voiceToUse)
                            
                            // Check cache first
                            if let cachedData = self.cache.getCachedAudio(for: cacheKey) {
                                return (index, cachedData)
                            }
                            
                            // If not cached, make API request
                            do {
                                let data = try await self.requestTTS(for: chunk, voice: voiceToUse)
                                self.cache.cacheAudio(data, for: cacheKey)
                                return (index, data)
                            } catch {
                                print("Error synthesizing chunk \(index): \(error.localizedDescription)")
                                return (index, nil)
                            }
                        }
                        activeRequests += 1
                    }
                }
                
                // Collect results
                for await result in group {
                    results.append(result)
                }
                
                return results.sorted { $0.0 < $1.0 }
            }
            
            // Process the results in order
            for (chunkIndex, chunkData) in chunks {
                if let data = chunkData {
                    // If this is the first chunk and we haven't sent it yet, send immediately
                    if !firstChunkSent && chunkIndex == 0 {
                        firstChunkSent = true
                        if let firstChunkPlayer = try? AVAudioPlayer(data: data) {
                            firstChunkPlayer.prepareToPlay()
                            onFirstChunkReady?(firstChunkPlayer)
                        }
                    }
                    
                    audioData.append(data)
                    processedChunks += 1
                    progressHandler?(Double(processedChunks) / Double(totalChunks))
                }
            }
        }
        
        // Create final audio player with all audio data
        guard let player = try? AVAudioPlayer(data: audioData) else {
            throw NSError(domain: "OpenAIService.synthesizeSpeech", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio player."])
        }
        
        player.prepareToPlay()
        return player
    }
    
    private func requestTTS(for text: String, voice: String) async throws -> Data {
        let startTime = Date()
        
        guard let apiKey = keychain.openAIAPIKey, !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIService.synthesizeSpeech", code: 0, userInfo: [NSLocalizedDescriptionKey: "API key is missing. Please set your OpenAI API key in Settings."])
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            throw NSError(domain: "OpenAIService.synthesizeSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL for TTS."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": voice,
            "response_format": "mp3"
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            throw NSError(domain: "OpenAIService.synthesizeSpeech", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body for TTS."])
        }
        request.httpBody = httpBody
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Record timing for performance optimization
        let requestTime = Date().timeIntervalSince(startTime)
        chunkManager.recordRequestTime(requestTime)
        recordConcurrentRequestTime(requestTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIService.synthesizeSpeech", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response for TTS."])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseString = String(data: data, encoding: .utf8) ?? "[Could not decode error response]"
            throw NSError(domain: "OpenAIService.synthesizeSpeech", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "TTS API request failed with status \(httpResponse.statusCode). Response: \(responseString)"])
        }
        
        return data
    }
    
    // Track concurrent request performance and adjust limits
    private func recordConcurrentRequestTime(_ time: TimeInterval) {
        concurrentRequestTimes.append(time)
        if concurrentRequestTimes.count > maxConcurrentTimeHistory {
            concurrentRequestTimes.removeFirst()
        }
        adjustConcurrentRequestLimit()
    }
    
    private func adjustConcurrentRequestLimit() {
        guard concurrentRequestTimes.count >= 2 else { return }
        
        let averageTime = concurrentRequestTimes.reduce(0, +) / Double(concurrentRequestTimes.count)
        let latestTime = concurrentRequestTimes.last!
        
        // If latest request is significantly slower than average, reduce concurrency
        if latestTime > averageTime * 1.5 && latestTime > 2.0 {
            maxConcurrentRequests = max(minConcurrentRequests, maxConcurrentRequests - 1)
            print("OpenAIService: Reduced concurrent requests to \(maxConcurrentRequests) due to slow response (\(String(format: "%.2f", latestTime))s)")
        }
        // If consistently fast, increase concurrency
        else if averageTime < 1.5 && maxConcurrentRequests < maxConcurrentRequestsLimit {
            maxConcurrentRequests = min(maxConcurrentRequestsLimit, maxConcurrentRequests + 1)
            print("OpenAIService: Increased concurrent requests to \(maxConcurrentRequests) due to good performance (\(String(format: "%.2f", averageTime))s avg)")
        }
    }
} 