import Foundation
import CommonCrypto

class AudioCache {
    static let shared = AudioCache()
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Set up cache directory in the app's cache directory
        let appCacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = appCacheDirectory.appendingPathComponent("TTSCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure cache limits
        cache.countLimit = 100 // Maximum number of cached items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    func getCachedAudio(for key: String) -> Data? {
        // First check memory cache
        if let cachedData = cache.object(forKey: key as NSString) {
            return Data(referencing: cachedData)
        }
        
        // Then check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256)
        if let data = try? Data(contentsOf: fileURL) {
            // Add to memory cache
            cache.setObject(data as NSData, forKey: key as NSString)
            return data
        }
        
        return nil
    }
    
    func cacheAudio(_ data: Data, for key: String) {
        // Cache in memory
        cache.setObject(data as NSData, forKey: key as NSString)
        
        // Cache to disk
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256)
        try? data.write(to: fileURL)
    }
    
    func clearCache() {
        // Clear memory cache
        cache.removeAllObjects()
        
        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// Extension to generate SHA256 hash for cache keys
extension String {
    var sha256: String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
} 