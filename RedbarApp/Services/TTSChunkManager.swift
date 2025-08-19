import Foundation
import AVFoundation

class TTSChunkManager: NSObject {
    private var maxChunkSize = 2000 // Dynamic - will adjust based on network performance
    private let initialChunkSize = 200 // Very small first chunk for immediate playback
    private let minChunkSize = 500 // Minimum chunk size for efficiency
    private let maxChunkSizeLimit = 4000 // Maximum allowed chunk size
    
    // Network performance tracking
    private var requestTimes: [TimeInterval] = []
    private let maxRequestTimeHistory = 5
    
    private var chunks: [String] = []
    private var currentChunkIndex = 0
    private var audioPlayers: [AVAudioPlayer] = []
    private var isPlaying = false
    private var completionHandler: (() -> Void)?
    
    override init() {
        super.init()
    }
    
    func prepareText(_ text: String) {
        chunks = splitIntoChunks(text)
        currentChunkIndex = 0
        audioPlayers.removeAll()
    }
    
    // Add public property to get total chunks count
    var totalChunks: Int {
        chunks.count
    }
    
    // Add public property to check if there are more chunks
    var hasMoreChunks: Bool {
        currentChunkIndex < chunks.count
    }
    
    // Add public method to get next chunk
    func nextChunk() -> String? {
        guard currentChunkIndex < chunks.count else { return nil }
        let chunk = chunks[currentChunkIndex]
        currentChunkIndex += 1
        return chunk
    }
    
    private func splitIntoChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        var remainingText = text
        
        // First chunk: Take a small portion for immediate playback
        if let firstPeriod = remainingText.range(of: ".", options: [], range: remainingText.startIndex..<remainingText.endIndex),
           firstPeriod.upperBound <= remainingText.index(remainingText.startIndex, offsetBy: initialChunkSize, limitedBy: remainingText.endIndex) ?? remainingText.endIndex {
            // Take up to the first period if it's within initialChunkSize
            let firstChunk = String(remainingText[..<firstPeriod.upperBound])
            chunks.append(firstChunk)
            remainingText = String(remainingText[firstPeriod.upperBound...])
        } else if remainingText.count > initialChunkSize {
            // If no period found, just take initialChunkSize characters
            let index = remainingText.index(remainingText.startIndex, offsetBy: initialChunkSize)
            let firstChunk = String(remainingText[..<index])
            chunks.append(firstChunk)
            remainingText = String(remainingText[index...])
        }
        
        // Rest of the text: Split by sentences with maxChunkSize limit
        let sentences = remainingText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var currentChunk = ""
        for sentence in sentences {
            if currentChunk.count + sentence.count + 1 <= maxChunkSize {
                if !currentChunk.isEmpty {
                    currentChunk += ". "
                }
                currentChunk += sentence
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk + ".")
                }
                currentChunk = sentence
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk + ".")
        }
        
        return chunks
    }
    
    func getCacheKey(for text: String, voice: String) -> String {
        return "\(text)_\(voice)".sha256
    }
    
    // Track network performance and adjust chunk size
    func recordRequestTime(_ time: TimeInterval) {
        requestTimes.append(time)
        if requestTimes.count > maxRequestTimeHistory {
            requestTimes.removeFirst()
        }
        adjustChunkSize()
    }
    
    private func adjustChunkSize() {
        guard requestTimes.count >= 3 else { return }
        
        let averageTime = requestTimes.reduce(0, +) / Double(requestTimes.count)
        
        // Adjust chunk size based on average request time
        if averageTime < 1.0 { // Fast network (< 1 second)
            maxChunkSize = min(maxChunkSizeLimit, maxChunkSize + 200)
        } else if averageTime > 3.0 { // Slow network (> 3 seconds)
            maxChunkSize = max(minChunkSize, maxChunkSize - 300)
        }
        // Medium performance (1-3 seconds) - keep current size
        
        print("TTSChunkManager: Adjusted chunk size to \(maxChunkSize) based on avg request time: \(String(format: "%.2f", averageTime))s")
    }
    
    // Get current optimal chunk size
    var currentMaxChunkSize: Int {
        return maxChunkSize
    }
    
    func addAudioPlayer(with data: Data) throws -> AVAudioPlayer {
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        audioPlayers.append(player)
        return player
    }
    
    func reset() {
        stopPlayback()
        chunks.removeAll()
        currentChunkIndex = 0
        audioPlayers.removeAll()
        completionHandler = nil
    }
    
    func stopPlayback() {
        isPlaying = false
        audioPlayers.forEach { $0.stop() }
    }
    
    func playAudioSequentially(completion: @escaping () -> Void) {
        isPlaying = true
        completionHandler = completion
        
        guard !audioPlayers.isEmpty else {
            completion()
            return
        }
        
        // Start playing the first audio file
        audioPlayers[0].play()
    }
}

extension TTSChunkManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isPlaying else { return }
        
        // Find the index of the current player
        if let currentIndex = audioPlayers.firstIndex(of: player),
           currentIndex + 1 < audioPlayers.count {
            // Play the next audio file
            audioPlayers[currentIndex + 1].play()
        } else {
            // All chunks have finished playing
            isPlaying = false
            completionHandler?()
        }
    }
}

 