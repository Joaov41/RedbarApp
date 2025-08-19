import SwiftUI
import Combine
import Kingfisher
// Add AppKit for window management
import AppKit
import AVFoundation // Keep for other AV types if any, though NSSound is primary here

// MARK: - App Icon Name (for Asset Catalog)
let customMenuBarIconName = "MenuBarIcon" // Add an image with this name to Assets.xcassets




// MARK: - Data Models

// Structure for gallery item metadata (within media_metadata)
struct MediaMetadataValue: Codable, Hashable {
    let id: String?          // Media ID
    let status: String?      // e.g., "valid"
    let e: String?           // Type, e.g., "Image", "AnimatedImage"
    let m: String?           // Mimetype, e.g., "image/jpeg"
    let p: [MediaItemPreview]? // Different resolutions for static images
    let s: MediaItemSource?    // Source URLs (highest quality, gif, mp4)
    // For videos, there might be `hlsUrl`, `dashUrl`, `isGif` fields too.

    // Helper to get a displayable image URL (preferring GIF, then highest quality static)
    var displayURLString: String? {
        if e == "AnimatedImage" { return s?.gif } // Prefer GIF for animated images
        return s?.u ?? p?.last?.u // Fallback to highest quality static or largest preview
    }
    
    static func == (lhs: MediaMetadataValue, rhs: MediaMetadataValue) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Structure for image/video previews (p in MediaMetadataValue)
struct MediaItemPreview: Codable, Hashable {
    let u: String? // URL of this preview
    let x: Int?    // Width
    let y: Int?    // Height
    
    static func == (lhs: MediaItemPreview, rhs: MediaItemPreview) -> Bool {
        lhs.u == rhs.u
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(u)
    }
}

// Structure for media item source URLs (s in MediaMetadataValue)
struct MediaItemSource: Codable, Hashable {
    let u: String?  // URL of the image (highest resolution usually)
    let gif: String?// URL of the GIF version (for animated images)
    let mp4: String?// URL of the MP4 version (for videos/animated images)
    let x: Int?     // Width
    let y: Int?     // Height
    
    static func == (lhs: MediaItemSource, rhs: MediaItemSource) -> Bool {
        lhs.u == rhs.u && lhs.gif == rhs.gif && lhs.mp4 == rhs.mp4
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(u)
        hasher.combine(gif)
        hasher.combine(mp4)
    }
}

struct RedditResponse: Codable {
    let kind: String
    let data: ListingData
}

struct ListingData: Codable {
    let children: [PostContainer]
    let after: String?
    let before: String?
    let dist: Int?
}

struct PostContainer: Codable {
    let kind: String
    let data: PostData
}

struct PostData: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let subreddit: String
    let score: Int
    let num_comments: Int
    let permalink: String
    let url: String
    let thumbnail: String?
    let created_utc: Double
    let is_self: Bool
    let spoiler: Bool?
    let over_18: Bool?
    let selftext: String?
    let is_gallery: Bool?
    let media_metadata: [String: MediaMetadataValue]?

    var fullPermalink: String { "https://www.reddit.com\(permalink)" }

    var displayThumbnailURL: URL? {
        guard let thumb = thumbnail,
              thumb != "self" && 
              thumb != "nsfw" && 
              thumb != "spoiler" && 
              thumb != "" && 
              thumb.starts(with: "http") 
        else { return nil }
        let decodedThumb = thumb.replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: decodedThumb)
    }

    var placeholderIconName: String {
        if spoiler == true { return "eye.slash.fill" }
        if over_18 == true && thumbnail == "nsfw" { return "exclamationmark.triangle.fill" }
        if is_self && (thumbnail == "self" || thumbnail == "") { return "text.bubble.fill" }
        if thumbnail == "default" || thumbnail == "" || thumbnail == "image" { return "photo.fill" }
        return "photo.fill"
    }

    static func == (lhs: PostData, rhs: PostData) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// Comment models
struct CommentResponse: Codable {
    let kind: String
    let data: CommentData
}

struct CommentData: Codable, Identifiable {
    let id: String?
    let author: String?
    let body: String?
    let score: Int?
    let created_utc: Double?
    let replies: CommentReplies?
    
    // Added fields to support nested comments and "more comments" functionality
    let children: [String]?    // For "more" comments
    let count: Int?            // For "more" comments count
    var depth: Int = 0         // Comment nesting level
    var nestedReplies: [CommentData] = [] // Parsed nested replies
    var isCollapsed: Bool = false // UI state for collapsible comments
    var moreCommentsAvailable: Bool = false // If this comment has "more" comments
    
    // For handling nested replies
    struct CommentReplies: Codable {
        let data: CommentListingData?
        
        // Empty replies come as an empty string
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self), string.isEmpty {
                data = nil
            } else {
                let nestedContainer = try decoder.container(keyedBy: CodingKeys.self)
                data = try nestedContainer.decodeIfPresent(CommentListingData.self, forKey: .data)
            }
        }
        
        // Custom initializer for previews
        init(data: CommentListingData? = nil) {
            self.data = data
        }
        
        enum CodingKeys: String, CodingKey {
            case data
        }
    }
    
    struct CommentListingData: Codable {
        let children: [CommentResponse]?
    }
    
    // Initialize with manual parsing
    init(
        id: String? = nil,
        author: String? = nil,
        body: String? = nil,
        score: Int? = nil,
        created_utc: Double? = nil,
        replies: CommentReplies? = nil,
        children: [String]? = nil, 
        count: Int? = nil,
        depth: Int = 0,
        nestedReplies: [CommentData] = [],
        isCollapsed: Bool = false,
        moreCommentsAvailable: Bool = false
    ) {
        self.id = id
        self.author = author
        self.body = body
        self.score = score
        self.created_utc = created_utc
        self.replies = replies
        self.children = children
        self.count = count
        self.depth = depth
        self.nestedReplies = nestedReplies
        self.isCollapsed = isCollapsed
        self.moreCommentsAvailable = moreCommentsAvailable
    }
    
    // Factory method to create a "more comments" placeholder
    static func moreCommentsPlaceholder(count: Int, childIds: [String], depth: Int) -> CommentData {
        return CommentData(
            id: "more_\(UUID().uuidString)",
            author: "[load more]",
            body: "Load \(count) more comments",
            children: childIds,
            count: count,
            depth: depth,
            moreCommentsAvailable: true
        )
    }
}

// MARK: - View Model

enum SortType: String, CaseIterable, Identifiable {
    case hot, new, top
    var id: String { self.rawValue }
}

struct RedditError: Codable {
    let reason: String?
    let message: String
    let error: Int?
}

@MainActor
class RedditViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate, NSSpeechSynthesizerDelegate {
    @Published var posts: [PostData] = []
    @Published var currentPostComments: [CommentData] = []
    @Published var isLoadingComments: Bool = false
    @Published var isLoadingMoreComments: Bool = false
    @Published var commentError: String? = nil
    @Published var replyingToId: String? = nil
    @Published var replyText: String = ""
    @Published var isPostingReply: Bool = false
    @Published var replyError: String? = nil
    @AppStorage("currentSubreddit") var subreddit: String = "swift"
    @AppStorage("currentSortTypeRaw") private var currentSortTypeRaw: String = SortType.hot.rawValue
    
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    
    // Summary-related state
    @Published var isSummarizing: Bool = false
    @Published var summary: String? = nil
    @Published var summaryError: String? = nil
    @Published var commentsSentToLLMCount: Int = 0
    @Published var shouldShowSettingsForGeminiKey: Bool = false
    
    // Summary cache
    private struct CachedSummary {
        let summary: String
        let timestamp: Date
        let postId: String
        let commentCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 600 // 10 minutes
        }
    }
    private var summaryCache: [String: CachedSummary] = [:]
    
    // Q&A conversation context
    private var conversationHistory: [String] = []
    private var currentPostForQA: String? = nil
    
    // TTS States
    @Published var isSynthesizingSpeech: Bool = false
    @Published var speechSynthesisError: String? = nil
    @Published var speechSynthesisProgress: Double = 0.0
    private var audioPlayer: AVAudioPlayer?
    private var remainingAudioPlayer: AVAudioPlayer?
    private var isPlayingFirstChunk: Bool = false
    
    // Local macOS TTS
    @Published var isSpeakingLocally: Bool = false
    private var localSpeechSynth: NSSpeechSynthesizer?
    
    // Answer TTS states
    @Published var isSynthesizingAnswerSpeech: Bool = false
    @Published var answerSpeechSynthesisProgress: Double = 0.0
    @Published var isSpeakingAnswerLocally: Bool = false
    var answerAudioPlayer: AVAudioPlayer?
    private var answerLocalSpeechSynth: NSSpeechSynthesizer?
    
    // Changed from private to internal (default) or public private(set)
    // Making it internal is fine for single-module apps like this.
    // If you want to be more explicit about read-only from outside:
    @Published private(set) var afterToken: String? = nil

    private var cancellables = Set<AnyCancellable>()

    @AppStorage("favoriteSubredditsData") private var favoriteSubredditsData: Data?
    @Published var favoriteSubreddits: [String] = []

    var currentSortType: SortType {
        get { SortType(rawValue: currentSortTypeRaw) ?? .hot }
        set { currentSortTypeRaw = newValue.rawValue }
    }

    // Track the current post for more comments loading
    private var currentPost: PostData? = nil

    override init() { // <-- Add override
        super.init() // <-- Call super.init()
        loadFavorites()
        // audioPlayer is initialized on demand
        cleanupExpiredSummaries()
    }
    
    // Clean up expired summaries from cache
    private func cleanupExpiredSummaries() {
        summaryCache = summaryCache.filter { !$0.value.isExpired }
    }

    // MARK: - Recursive Comment Tree Helpers

    private func findAndReplaceMoreComment(
        in comments: inout [CommentData],
        targetId: String,
        newlyLoadedItems: [CommentData],
        continuationItem: CommentData?
    ) -> Bool {
        for i in 0..<comments.count {
            if comments[i].id == targetId && comments[i].moreCommentsAvailable {
                // Found the placeholder
                comments.remove(at: i)
                var insertionIndex = i
                comments.insert(contentsOf: newlyLoadedItems, at: insertionIndex)
                insertionIndex += newlyLoadedItems.count
                if let continuation = continuationItem {
                    comments.insert(continuation, at: insertionIndex)
                }
                return true // Replacement done
            }
            // Recursively search in nested replies
            if findAndReplaceMoreComment(
                in: &comments[i].nestedReplies,
                targetId: targetId,
                newlyLoadedItems: newlyLoadedItems,
                continuationItem: continuationItem
            ) {
                return true // Replacement done in a deeper level
            }
        }
        return false // Not found at this level or in children
    }

    private func findAndRemoveMoreComment(
        in comments: inout [CommentData],
        targetId: String
    ) -> Bool {
        for i in 0..<comments.count {
            if comments[i].id == targetId && comments[i].moreCommentsAvailable {
                comments.remove(at: i)
                return true // Removal done
            }
            // Recursively search in nested replies
            if findAndRemoveMoreComment(in: &comments[i].nestedReplies, targetId: targetId) {
                return true // Removal done in a deeper level
            }
        }
        return false // Not found
    }
    
    private func findAndToggleCollapse(in comments: inout [CommentData], targetId: String) -> Bool {
        for i in 0..<comments.count {
            if comments[i].id == targetId {
                comments[i].isCollapsed.toggle()
                // If expanding a comment, also expand its direct children if they were previously collapsed due to parent.
                // This is optional behavior, can be adjusted. For now, just toggle the target.
                return true
            }
            if findAndToggleCollapse(in: &comments[i].nestedReplies, targetId: targetId) {
                return true
            }
        }
        return false
    }

    // MARK: - Post Fetching

    func fetchFullPost(for post: PostData, completion: @escaping (PostData?) -> Void) {
        let urlString = "https://www.reddit.com\(post.permalink).json"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any]
                if let postListing = jsonArray?[0] as? [String: Any],
                   let postData = postListing["data"] as? [String: Any],
                   let children = postData["children"] as? [[String: Any]],
                   let firstPost = children.first,
                   let firstPostData = firstPost["data"] as? [String: Any],
                   let fullSelftext = firstPostData["selftext"] as? String {
                    
                    let updatedPost = PostData(
                        id: post.id,
                        title: post.title,
                        author: post.author,
                        subreddit: post.subreddit,
                        score: post.score,
                        num_comments: post.num_comments,
                        permalink: post.permalink,
                        url: post.url,
                        thumbnail: post.thumbnail,
                        created_utc: post.created_utc,
                        is_self: post.is_self,
                        spoiler: post.spoiler,
                        over_18: post.over_18,
                        selftext: fullSelftext,
                        is_gallery: post.is_gallery,
                        media_metadata: post.media_metadata
                    )
                    
                    DispatchQueue.main.async {
                        completion(updatedPost)
                    }
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    func fetchPosts(isLoadingMore: Bool = false) {
        let trimmedSubreddit = subreddit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubreddit.isEmpty else {
            errorMessage = "Subreddit name cannot be empty."
            posts = []
            return
        }

        if isLoadingMore {
            self.isLoadingMore = true
        } else {
            self.isLoading = true
            self.posts = []
            self.afterToken = nil
        }
        self.errorMessage = nil
        
        var urlString = "https://www.reddit.com/r/\(trimmedSubreddit)/\(currentSortType.rawValue).json?limit=20"
        if isLoadingMore, let token = self.afterToken { // Access self.afterToken
            urlString += "&after=\(token)"
        }
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            self.isLoading = false
            self.isLoadingMore = false
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    var specificMessage = "Server error. Status: \((output.response as? HTTPURLResponse)?.statusCode ?? 0)"
                    if let redditError = try? JSONDecoder().decode(RedditError.self, from: output.data) {
                        specificMessage = "Reddit API Error: \(redditError.message) (Reason: \(redditError.reason ?? "Unknown"))"
                    }
                    throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: specificMessage])
                }
                return output.data
            }
            .decode(type: RedditResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                self.isLoadingMore = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                    if !isLoadingMore { self.posts = [] }
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                let newPosts = response.data.children.map { $0.data }
                if isLoadingMore {
                    self.posts.append(contentsOf: newPosts)
                } else {
                    self.posts = newPosts
                }
                self.afterToken = response.data.after
                
                // Fetch full text for text posts
                for post in newPosts where post.is_self {
                    self.fetchFullPost(for: post) { updatedPost in
                        if let updatedPost = updatedPost,
                           let index = self.posts.firstIndex(where: { $0.id == updatedPost.id }) {
                            self.posts[index] = updatedPost
                        }
                    }
                }
                
                if self.posts.isEmpty && !isLoadingMore {
                    self.errorMessage = "No posts found for r/\(trimmedSubreddit)."
                }
            })
            .store(in: &cancellables)
    }

    private func loadFavorites() {
        guard let data = favoriteSubredditsData,
              let decodedFavorites = try? JSONDecoder().decode([String].self, from: data) else { return }
        favoriteSubreddits = decodedFavorites.sorted()
    }

    private func saveFavorites() {
        if let encodedFavorites = try? JSONEncoder().encode(favoriteSubreddits.sorted()) {
            favoriteSubredditsData = encodedFavorites
        }
    }

    func addSubredditToFavorites(_ subName: String) {
        let cleanedSubName = subName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSubName.isEmpty, !favoriteSubreddits.contains(where: { $0.caseInsensitiveCompare(cleanedSubName) == .orderedSame }) else { return }
        favoriteSubreddits.append(cleanedSubName)
        saveFavorites()
    }
    
    func addCurrentSubredditToFavorites() { addSubredditToFavorites(self.subreddit) }

    func removeFavorite(subredditNameToRemove: String) {
        favoriteSubreddits.removeAll { $0.caseInsensitiveCompare(subredditNameToRemove) == .orderedSame }
        saveFavorites()
    }

    func selectFavorite(_ favoriteSubreddit: String) {
        self.subreddit = favoriteSubreddit
        fetchPosts()
    }

    func isCurrentSubredditFavorite() -> Bool {
        let cleanedCurrentSub = subreddit.trimmingCharacters(in: .whitespacesAndNewlines)
        return favoriteSubreddits.contains { $0.caseInsensitiveCompare(cleanedCurrentSub) == .orderedSame }
    }

    // Fetch comments for a specific post
    func fetchComments(for post: PostData) {
        isLoadingComments = true
        currentPostComments = []
        commentError = nil
        currentPost = post // Store post for more comments loading
        
        // Check for cached summary first
        let cacheKey = "\(post.id)_\(post.num_comments)"
        if let cached = summaryCache[cacheKey], !cached.isExpired {
            summary = cached.summary
            summaryError = nil
            commentsSentToLLMCount = cached.commentCount
        } else {
            // Reset summary-related state when loading a new post
            summary = nil
            summaryError = nil
            commentsSentToLLMCount = 0
            // Remove expired cache entry
            summaryCache.removeValue(forKey: cacheKey)
        }
        
        // Reddit API returns post and comments together in an array
        // First element is the post, second element is the comment tree
        let urlString = "https://www.reddit.com\(post.permalink).json"
        print("Fetching comments from: \(urlString)")
        
        fetchRedditComments(url: urlString) { success in
            if !success {
                // If we fail, try without .json
                let fallbackUrl = "https://www.reddit.com\(post.permalink)"
                print("Trying fallback URL: \(fallbackUrl)")
                self.fetchRedditComments(url: fallbackUrl)
            }
        }
    }
    
    // Load more comments for a specific "more" comment placeholder
    // This function is called from SwiftUI, so it runs on the MainActor.
    func loadMoreComments(for moreComment: CommentData) {
        guard let currentPost = self.currentPost else { // self.currentPost is @MainActor isolated
            print("Missing currentPost for loading more comments (UI triggered)")
            return
        }

        // Ensure the placeholder has children to load.
        guard moreComment.children != nil, !(moreComment.children?.isEmpty ?? true) else {
            print("UI loadMoreComments: MoreComment has no children or children array is empty. ID: \(moreComment.id ?? "unknown")")
            // Attempt to remove this placeholder as it's invalid or empty.
            _ = self.findAndRemoveMoreComment(in: &self.currentPostComments, targetId: moreComment.id ?? "")
            return
        }

        self.isLoadingMoreComments = true // Directly set, as we are on MainActor

        Task { // This Task inherits MainActor
            defer { self.isLoadingMoreComments = false } // Runs when Task finishes, on MainActor

            do {
                // performLoadMoreCommentsRequest is NOT @MainActor, so it will run off main thread.
                let (parsedNewItems, continuationItem) = try await self.performLoadMoreCommentsRequest(for: moreComment, currentPost: currentPost)
                
                // Back on MainActor here to update @Published property currentPostComments
                if !parsedNewItems.isEmpty || continuationItem != nil {
                    let success = self.findAndReplaceMoreComment(
                        in: &self.currentPostComments,
                        targetId: moreComment.id ?? "",
                        newlyLoadedItems: parsedNewItems,
                        continuationItem: continuationItem
                    )
                    if !success {
                        print("Error: UI loadMoreComments - Could not find and replace placeholder ID: \(moreComment.id ?? "")")
                    }
                } else {
                    // API returned nothing, and there's no continuation. Placeholder was empty or resolved. Remove it.
                    print("UI loadMoreComments: No new comments or continuation for \(moreComment.id ?? ""). Removing placeholder.")
                    _ = self.findAndRemoveMoreComment(in: &self.currentPostComments, targetId: moreComment.id ?? "")
                }
            } catch {
                print("Error in UI-triggered loadMoreComments: \(error.localizedDescription)")
                // Optionally set an error message for the UI
                // self.commentError = "Failed to load more comments: \(error.localizedDescription)"
            }
        }
    }

    // New private async function to handle the actual network request for more comments.
    // This function is NOT @MainActor and performs network operations.
    private func performLoadMoreCommentsRequest(for moreComment: CommentData, currentPost: PostData) async throws -> (newlyLoadedItems: [CommentData], continuationItem: CommentData?) {
        guard let children = moreComment.children, !children.isEmpty else {
            // This case means the "moreComment" placeholder itself has no children IDs.
            // It implies it was likely an empty "more" node or previously fully resolved.
            print("performLoadMoreCommentsRequest: MoreComment has no children. ID: \(moreComment.id ?? "unknown")")
            return ([], nil) // Signal to caller to remove the placeholder
        }

        let commentIds = children.prefix(20).joined(separator: ",") // Reddit API limit
        let urlString = "https://www.reddit.com/api/morechildren.json?link_id=t3_\(currentPost.id)&children=\(commentIds)&api_type=json"
        print("performLoadMoreCommentsRequest: Loading more comments from URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "RedditViewModel.performLoadMoreCommentsRequest", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for more comments: \(urlString)"])
        }

        var request = URLRequest(url: url)
        request.addValue("macOS:RedditMenuBarReader:v1.0 (by /u/yourUsername)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("performLoadMoreCommentsRequest: Error loading more comments. Status: \(statusCode). URL: \(urlString)")
            throw NSError(domain: "RedditViewModel.performLoadMoreCommentsRequest", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to load more comments. HTTP Status: \(statusCode)"])
        }

        // Parse the JSON response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jsonData = json["json"] as? [String: Any],
              let thingsContainer = jsonData["data"] as? [String: Any],
              let apiResponseItems = thingsContainer["things"] as? [[String: Any]] else {
            print("performLoadMoreCommentsRequest: Could not parse 'things' from more_children response or unexpected structure. URL: \(urlString)")
            throw NSError(domain: "RedditViewModel.performLoadMoreCommentsRequest", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure in more_children response."])
        }
        
        var parsedNewItems: [CommentData] = []
        for itemJson in apiResponseItems {
            // itemJson is already a dictionary like {"kind": "...", "data": {...}}
            if let parsedItem = self.parseCommentJson(itemJson, depth: moreComment.depth) { // parseCommentJson needs to be MainActor-safe if it accesses ViewModel state, but it seems okay as it's a pure parser.
                parsedNewItems.append(parsedItem)
            }
        }
        
        // Determine if a continuation placeholder is needed for children not covered by this API call
        var continuationPlaceholder: CommentData? = nil
        let requestedChildrenCount = 20 // Max items typically requested from morechildren
        
        if children.count > requestedChildrenCount {
            let remainingIds = Array(children.dropFirst(requestedChildrenCount))
            if !remainingIds.isEmpty { // Only create if there are actually remaining IDs
                continuationPlaceholder = CommentData.moreCommentsPlaceholder(
                    count: remainingIds.count,
                    childIds: remainingIds,
                    depth: moreComment.depth
                )
            }
        }
        
        return (parsedNewItems, continuationPlaceholder)
    }
    
    // Helper method to find comment index in the comments array (No longer primary way to update, consider for removal if not used elsewhere)
    // private func findCommentIndex(commentId: String) -> Int? {
    // return currentPostComments.firstIndex(where: { $0.id == commentId })
    // }
    
    // Update a comment's collapsed state
    func toggleCommentCollapsed(commentId: String) {
        if !findAndToggleCollapse(in: &currentPostComments, targetId: commentId) {
            print("Warning: Could not find comment with ID \(commentId) to toggle collapse state.")
        }
    }
    
    // Helper method to fetch comments from Reddit
    private func fetchRedditComments(url urlString: String, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: urlString) else {
            commentError = "Invalid URL for comments"
            isLoadingComments = false
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("macOS:RedditMenuBarReader:v1.0 (by /u/yourUsername)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoadingComments = false
                
                if let error = error {
                    self.commentError = "Network error: \(error.localizedDescription)"
                    print("Comment fetch error: \(error)")
                    completion?(false)
                    return
                }
                
                guard let data = data else {
                    self.commentError = "No data received"
                    completion?(false)
                    return
                }
                
                // Check for Reddit API errors that return HTTP 200 but with an error message
                if let responseString = String(data: data, encoding: .utf8),
                   responseString.contains("\"error\":") {
                    print("Reddit API returned an error: \(responseString)")
                    self.commentError = "Reddit API error - try again later"
                    completion?(false)
                    return
                }
                
                do {
                    // Debug: Print a sample of the response
                    if let jsonStr = String(data: data.prefix(200), encoding: .utf8) {
                        print("Response preview: \(jsonStr)...")
                    }
                    
                    // Decode the array response
                    let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any]
                    
                    guard let jsonArray = jsonArray, jsonArray.count > 1 else {
                        self.commentError = "Invalid response format"
                        completion?(false)
                        return
                    }
                    
                    // Process comments listing (second element in the array)
                    guard let commentsListing = jsonArray[1] as? [String: Any],
                          let commentsData = commentsListing["data"] as? [String: Any],
                          let children = commentsData["children"] as? [[String: Any]] else {
                        self.commentError = "Could not find comments in response"
                        completion?(false)
                        return
                    }
                    
                    // Process first element to get updated post details
                    if let postListing = jsonArray[0] as? [String: Any],
                       let postData = postListing["data"] as? [String: Any],
                       let postChildren = postData["children"] as? [[String: Any]],
                       postChildren.count > 0,
                       let firstPost = postChildren[0] as? [String: Any],
                       let firstPostData = firstPost["data"] as? [String: Any],
                       let selftext = firstPostData["selftext"] as? String,
                       !selftext.isEmpty {
                        // We found updated selftext for the post - could update our post data here if needed
                        print("Found post selftext: \(selftext.prefix(50))...")
                    }
                    
                    // Parse each comment with a recursive approach to handle nesting
                    var parsedComments: [CommentData] = []
                    
                    for child in children {
                        if let comment = self.parseCommentJson(child, depth: 0) {
                            parsedComments.append(comment)
                        }
                    }
                    
                    if !parsedComments.isEmpty {
                        self.currentPostComments = parsedComments
                        print("Parsed \(parsedComments.count) comments (including nested)")
                        completion?(true)
                    } else {
                        print("No comments found or all comments were deleted")
                        self.commentError = "No comments found"
                        completion?(false)
                    }
                } catch {
                    self.commentError = "Error parsing comments: \(error.localizedDescription)"
                    print("Comment parsing error: \(error)")
                    completion?(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Authenticated API Methods
    
    private func makeAuthenticatedRequest(url: URL, method: String = "GET", body: Data? = nil) async throws -> Data {
        let authManager = RedditAuthManager.shared
        
        // Ensure we have an access token
        guard authManager.isAuthenticated else {
            throw RedditAuthError.noAccessToken
        }
        
        // Refresh token if needed
        await authManager.refreshTokenIfNeeded()
        
        guard let accessToken = authManager.accessToken else {
            throw RedditAuthError.noAccessToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("RedbarApp/1.0", forHTTPHeaderField: "User-Agent")
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                // Token expired, try to refresh and retry once
                await authManager.refreshTokenIfNeeded()
                if let newToken = authManager.accessToken {
                    request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: request)
                    return retryData
                }
                throw RedditAuthError.noAccessToken
            } else if httpResponse.statusCode >= 400 {
                throw RedditAuthError.networkError(NSError(domain: "Reddit", code: httpResponse.statusCode))
            }
        }
        
        return data
    }
    
    func postComment(parentId: String, text: String) async throws -> CommentData {
        let url = URL(string: "https://oauth.reddit.com/api/comment")!
        
        let parameters = [
            "thing_id": parentId,
            "text": text,
            "api_type": "json"
        ]
        
        let body = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let data = try await makeAuthenticatedRequest(url: url, method: "POST", body: body)
        
        // Parse the response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jsonData = json["json"] as? [String: Any],
              let responseData = jsonData["data"] as? [String: Any],
              let things = responseData["things"] as? [[String: Any]],
              let firstThing = things.first,
              let commentData = firstThing["data"] as? [String: Any],
              let id = commentData["id"] as? String,
              let author = commentData["author"] as? String,
              let bodyText = commentData["body"] as? String else {
            throw RedditAuthError.invalidResponse
        }
        
        // Create CommentData from the response
        let createdUtc = commentData["created_utc"] as? Double ?? Date().timeIntervalSince1970
        let score = commentData["score"] as? Int ?? 1
        
        // Determine depth based on parent ID prefix
        let depth = parentId.hasPrefix("t3_") ? 0 : 1 // t3_ is post, t1_ is comment
        
        return CommentData(
            id: id,
            author: author,
            body: bodyText,
            score: score,
            created_utc: createdUtc,
            replies: nil,
            children: nil,
            count: nil,
            depth: depth,
            nestedReplies: [],
            isCollapsed: false,
            moreCommentsAvailable: false
        )
    }
    
    // Recursive helper to parse comment JSON with nested replies
    private func parseCommentJson(_ json: [String: Any], depth: Int) -> CommentData? {
        guard let kind = json["kind"] as? String else { return nil }
        
        if kind == "t1" { // Regular comment
            guard let data = json["data"] as? [String: Any] else { return nil }
            
            // Extract basic comment properties
            let id = data["id"] as? String
            let author = data["author"] as? String
            let body = data["body"] as? String
            let score = data["score"] as? Int
            let createdUtc = data["created_utc"] as? Double
            
            // Only skip if we have absolutely no useful information
            if (author == nil || author == "[deleted]") && 
               (body == nil || body == "[deleted]") && 
               score == nil && 
               createdUtc == nil {
                return nil
            }
            
            // Parse nested replies
            var nestedReplies: [CommentData] = []
            
            if let repliesJson = data["replies"] as? [String: Any],
               let repliesData = repliesJson["data"] as? [String: Any],
               let repliesChildren = repliesData["children"] as? [[String: Any]] {
                
                for replyJson in repliesChildren {
                    if let reply = parseCommentJson(replyJson, depth: depth + 1) {
                        nestedReplies.append(reply)
                    }
                }
            }
            
            // Create CommentData
            let comment = CommentData(
                id: id,
                author: author,
                body: body,
                score: score,
                created_utc: createdUtc,
                depth: depth,
                nestedReplies: nestedReplies
            )
            
            return comment
            
        } else if kind == "more" { // "Load more comments" indicator
            guard let data = json["data"] as? [String: Any] else { return nil }
            
            let count = data["count"] as? Int ?? 0
            let children = data["children"] as? [String] ?? []
            
            if count > 0 && !children.isEmpty {
                return CommentData.moreCommentsPlaceholder(
                    count: count,
                    childIds: children,
                    depth: depth
                )
            }
        }
        
        return nil
    }

    // MARK: - Comment Summarization
    
    // Helper function to find all "Load More" comments
    private func findAllMoreComments(in comments: [CommentData]) -> [CommentData] {
        var moreComments: [CommentData] = []
        
        for comment in comments {
            // Add this comment if it's a "more" comment with actual children to load
            if comment.moreCommentsAvailable, 
               let count = comment.count, count > 0,
               let children = comment.children, !children.isEmpty {
                moreComments.append(comment)
            }
            
            // Recursively search nested replies
            moreComments.append(contentsOf: findAllMoreComments(in: comment.nestedReplies))
        }
        
        return moreComments
    }
    
    // Function to load all remaining comments sequentially using the new async request function.
    // This function runs on the MainActor because it updates @Published properties.
    // Network calls within it (`performLoadMoreCommentsRequest`) are non-MainActor.
    private func loadAllRemainingComments() async throws {
        self.isLoadingMoreComments = true // Update UI state immediately
        defer {
            self.isLoadingMoreComments = false // Ensure UI state is reset when done or if an error occurs
        }

        while true {
            // Accessing currentPostComments (Published) on MainActor
            let moreCommentsToLoad = findAllMoreComments(in: self.currentPostComments)
            
            if moreCommentsToLoad.isEmpty {
                print("loadAllRemainingComments: No more 'more' comments to load.")
                break // All "more" comments have been loaded
            }

            print("loadAllRemainingComments: Found \(moreCommentsToLoad.count) 'more' comment nodes to process.")

            for individualMoreComment in moreCommentsToLoad {
                guard let strongCurrentPost = self.currentPost else {
                    print("loadAllRemainingComments: currentPost is nil. Cannot load more.")
                    throw NSError(domain: "RedditViewModel.loadAllRemainingComments", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Current post not found during loadAllRemainingComments."])
                }

                // Double-check if this placeholder still needs loading (it might have been processed if multiple point to same underlying data)
                // This is implicitly handled by findAndReplaceMoreComment/findAndRemoveMoreComment not finding the ID if already processed.

                print("loadAllRemainingComments: Processing 'more' node ID: \(individualMoreComment.id ?? "unknown") with \(individualMoreComment.children?.count ?? 0) children IDs.")

                do {
                    // performLoadMoreCommentsRequest is NOT @MainActor
                    let (newlyLoadedItems, continuationItem) = try await self.performLoadMoreCommentsRequest(for: individualMoreComment, currentPost: strongCurrentPost)
                    
                    // Update currentPostComments (Published) on MainActor
                    if !newlyLoadedItems.isEmpty || continuationItem != nil {
                        let success = self.findAndReplaceMoreComment(
                            in: &self.currentPostComments,
                            targetId: individualMoreComment.id ?? "",
                            newlyLoadedItems: newlyLoadedItems,
                            continuationItem: continuationItem
                        )
                        if !success {
                            print("Warning: loadAllRemainingComments - Could not find and replace placeholder ID: \(individualMoreComment.id ?? ""). It might have been processed already or tree structure changed.")
                        } else {
                            print("loadAllRemainingComments: Successfully replaced/updated 'more' node ID: \(individualMoreComment.id ?? "") with \(newlyLoadedItems.count) new items and \(continuationItem != nil ? "a" : "no") continuation.")
                        }
                    } else {
                        // API indicated this node is now empty or resolved without new items. Remove it.
                        print("loadAllRemainingComments: No new items/continuation for 'more' node ID: \(individualMoreComment.id ?? ""). Removing placeholder.")
                         _ = self.findAndRemoveMoreComment(in: &self.currentPostComments, targetId: individualMoreComment.id ?? "")
                    }
                } catch {
                    print("Error loading a batch of 'more' comments in loadAllRemainingComments for ID \(individualMoreComment.id ?? "unknown"): \(error.localizedDescription). Aborting further loading for summarization/Q&A.")
                    // Propagate the error to stop the summarization/Q&A process
                    throw error 
                }
            }
        }
        print("loadAllRemainingComments: Finished iterating through all found 'more' comment nodes.")
    }

    // Modified summarizeComments function
    func summarizeComments() {
        // Check for Gemini API key first
        let keychain = KeychainService.shared
        guard let apiKey = keychain.geminiAPIKey, !apiKey.isEmpty else {
            shouldShowSettingsForGeminiKey = true
            summaryError = "Gemini API key is required. Please add it in Settings."
            return
        }
        
        guard !currentPostComments.isEmpty else {
            summaryError = "No comments to summarize"
            return
        }

        // 1. Get initial count and update UI
        let initialFlattenedComments = flattenComments(comments: currentPostComments)
        DispatchQueue.main.async {
            self.commentsSentToLLMCount = initialFlattenedComments.count
        }

        isSummarizing = true
        summaryError = nil
        summary = nil

        Task {
            do {
                // Show loading state for comment loading, including initial count
                DispatchQueue.main.async {
                    self.summary = "Loading all comments... (found \(initialFlattenedComments.count) initially)"
                }

                // Load all remaining comments first (uses the new async implementation)
                try await loadAllRemainingComments()

                // Get final comment count for logging and UI
                let finalFlattenedComments = flattenComments(comments: currentPostComments)
                let totalComments = countAllComments(comments: currentPostComments) // Use countAllComments for the "Total comments found" log
                print("Total comments found after loading all: \(totalComments)")

                DispatchQueue.main.async {
                    self.commentsSentToLLMCount = finalFlattenedComments.count // Update UI with final count
                }
                print("Comments being sent to LLM: \(finalFlattenedComments.count)")

                let commentsText = finalFlattenedComments.joined(separator: "\\n\\n")

                let prompt = """
                Provide a SHORT summary of the key themes and main points from ALL the comments provided below. Keep the entire summary brief and concise.

                \(commentsText)
                """

                let result = try await GeminiService.shared.summarize(text: prompt)

                DispatchQueue.main.async {
                    self.summary = result
                    self.isSummarizing = false
                    
                    // Cache the summary
                    if let currentPost = self.currentPost {
                        let cacheKey = "\(currentPost.id)_\(currentPost.num_comments)"
                        self.summaryCache[cacheKey] = CachedSummary(
                            summary: result,
                            timestamp: Date(),
                            postId: currentPost.id,
                            commentCount: finalFlattenedComments.count
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.summaryError = "Error during summarization: \(error.localizedDescription)"
                    self.isSummarizing = false
                }
            }
        }
    }

    // Modified askQuestionAboutComments function
    func askQuestionAboutComments(question: String) async throws -> String {
        guard !currentPostComments.isEmpty else {
            throw NSError(domain: "CommentQA", code: 1, userInfo: [NSLocalizedDescriptionKey: "No comments available to analyze"])
        }
        
        // Check if this is a new post - reset conversation if so
        let currentPostId = currentPost?.id ?? ""
        if currentPostForQA != currentPostId {
            conversationHistory.removeAll()
            currentPostForQA = currentPostId
        }

        // 1. Get initial count and update UI (remains on MainActor due to @Published access)
        let initialFlattenedComments = flattenComments(comments: currentPostComments)
        self.commentsSentToLLMCount = initialFlattenedComments.count
        
        // Load all remaining comments first (uses the new async implementation)
        try await loadAllRemainingComments()

        // Get final comment count for logging and UI
        let finalFlattenedComments = flattenComments(comments: currentPostComments)
        let totalComments = countAllComments(comments: currentPostComments)
        print("Total comments for Q&A after loading all: \(totalComments)")

        DispatchQueue.main.async {
            self.commentsSentToLLMCount = finalFlattenedComments.count // Update UI with final count
        }
        print("Comments being sent to LLM for Q&A: \(finalFlattenedComments.count)")

        let commentsText = finalFlattenedComments.joined(separator: "\\n\\n")
        
        // Build conversation context
        var contextualPrompt = """
        Let's consider the following Reddit comments:

        \(commentsText)
        
        """
        
        // Add conversation history if it exists
        if !conversationHistory.isEmpty {
            contextualPrompt += "\nPrevious conversation:\n"
            contextualPrompt += conversationHistory.joined(separator: "\n")
            contextualPrompt += "\n"
        }
        
        contextualPrompt += "Answer the following question based on the information in the comments above"
        if !conversationHistory.isEmpty {
            contextualPrompt += " and our previous conversation"
        }
        contextualPrompt += ": \(question)"

        let answer = try await GeminiService.shared.summarize(text: contextualPrompt)
        
        // Add this Q&A to conversation history
        conversationHistory.append("Q: \(question)")
        conversationHistory.append("A: \(answer)")
        
        // Keep conversation history manageable (last 10 exchanges)
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(2)
        }
        
        return answer
    }

    // Counts all comments including all nested replies recursively
    private func countAllComments(comments: [CommentData]) -> Int {
        var count = 0
        
        for comment in comments {
            // Only count if the comment has any useful information
            if !(comment.author == nil && comment.body == nil && comment.score == nil && comment.created_utc == nil) {
                count += 1
            }
            
            // Count all replies recursively
            count += countAllComments(comments: comment.nestedReplies)
            
            // Count "more comments" placeholders
            if comment.moreCommentsAvailable, let moreCount = comment.count, moreCount > 0 {
                count += 1  // Count the placeholder itself
            }
        }
        
        return count
    }

    // Properly flattens the comment tree into a list of formatted comment strings
    private func flattenComments(comments: [CommentData], depth: Int = 0) -> [String] {
        var allRawComments = [String]()
        let indent = String(repeating: "    ", count: depth)
        
        for comment in comments {
            // Only skip if we have absolutely no useful information
            if (comment.author == nil || comment.author == "[deleted]") && 
               (comment.body == nil || comment.body == "[deleted]") && 
               comment.score == nil && 
               comment.created_utc == nil {
                continue
            }
            
            // Format the comment, preserving more information
            let authorText = comment.author ?? "[deleted]"
            let bodyText = comment.body ?? "[deleted]"
            let scoreText = comment.score != nil ? "\(comment.score!) points" : "? points"
            let formattedComment = "\(indent)- u/\(authorText) (\(scoreText)): \(bodyText)"
            allRawComments.append(formattedComment)
            
            // Process nested replies recursively
            if !comment.nestedReplies.isEmpty {
                allRawComments.append(contentsOf: flattenComments(comments: comment.nestedReplies, depth: depth + 1))
            }
            
            // If there are more comments available, add a note about it
            if comment.moreCommentsAvailable, let count = comment.count, count > 0 {
                allRawComments.append("\(indent)  [Note: \(count) more replies available]")
            }
        }
        
        return allRawComments
    }
    
    // MARK: - Text-to-Speech
    
    func speakSummary() {
        guard let summaryToSpeak = summary, !summaryToSpeak.isEmpty else {
            speechSynthesisError = "No summary available to read."
            return
        }
        
        // Stop any currently playing sound before starting a new one
        audioPlayer?.stop()
        audioPlayer = nil
        remainingAudioPlayer?.stop()
        remainingAudioPlayer = nil
        isPlayingFirstChunk = false
        
        // Also stop any answer audio
        answerAudioPlayer?.stop()
        stopAnswerLocalSpeech()
        
        isSynthesizingSpeech = true
        speechSynthesisProgress = 0.0
        speechSynthesisError = nil
        
        Task {
            do {
                let completePlayer = try await OpenAIService.shared.synthesizeSpeech(
                    text: summaryToSpeak,
                    progressHandler: { [weak self] progress in
                        DispatchQueue.main.async {
                            self?.speechSynthesisProgress = progress
                        }
                    },
                    onFirstChunkReady: { [weak self] firstChunkPlayer in
                        DispatchQueue.main.async {
                            // Start playing the first chunk immediately for quick response
                            self?.audioPlayer = firstChunkPlayer
                            self?.audioPlayer?.delegate = self
                            self?.isPlayingFirstChunk = true
                            if self?.audioPlayer?.play() == true {
                                // First chunk playing - user gets immediate audio
                            } else {
                                self?.speechSynthesisError = "Failed to start initial audio playback."
                                self?.isSynthesizingSpeech = false
                                self?.isPlayingFirstChunk = false
                            }
                        }
                    }
                )
                
                DispatchQueue.main.async {
                    // Replace with complete audio - stop first chunk and play complete
                    self.audioPlayer?.stop()
                    self.audioPlayer = completePlayer
                    self.audioPlayer?.delegate = self
                    self.isPlayingFirstChunk = false
                    
                    if self.audioPlayer?.play() == true {
                        // Complete audio playing successfully
                    } else {
                        self.speechSynthesisError = "Failed to start complete audio playback."
                        self.isSynthesizingSpeech = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.speechSynthesisError = "Speech synthesis failed: \(error.localizedDescription)"
                    self.isSynthesizingSpeech = false
                }
            }
        }
    }
    
    func stopSpeech() {
        audioPlayer?.stop()
        audioPlayer = nil
        remainingAudioPlayer?.stop()
        remainingAudioPlayer = nil
        isPlayingFirstChunk = false
        isSynthesizingSpeech = false
        speechSynthesisProgress = 0.0
    }

    func speakAnswer(answer: String) {
        guard !answer.isEmpty else {
            speechSynthesisError = "No answer available to read."
            return
        }
        
        // Stop any currently playing sound before starting a new one
        answerAudioPlayer?.stop()
        answerAudioPlayer = nil
        
        // Also stop any summary audio
        audioPlayer?.stop()
        remainingAudioPlayer?.stop()
        remainingAudioPlayer = nil
        isPlayingFirstChunk = false
        stopLocalSpeech()
        
        isSynthesizingAnswerSpeech = true
        answerSpeechSynthesisProgress = 0.0
        speechSynthesisError = nil
        
        Task {
            do {
                let completePlayer = try await OpenAIService.shared.synthesizeSpeech(
                    text: answer,
                    progressHandler: { [weak self] progress in
                        DispatchQueue.main.async {
                            self?.answerSpeechSynthesisProgress = progress
                        }
                    }
                )
                
                DispatchQueue.main.async {
                    // Simply use the complete audio - no chunking complexity
                    self.answerAudioPlayer = completePlayer
                    self.answerAudioPlayer?.delegate = self
                    if self.answerAudioPlayer?.play() == true {
                        // Audio playing successfully
                    } else {
                        self.speechSynthesisError = "Failed to start answer audio playback."
                        self.isSynthesizingAnswerSpeech = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if (error as NSError).domain == "OpenAIService.synthesizeSpeech" && (error as NSError).code == 0 {
                        self.speechSynthesisError = "OpenAI API key is missing. Please add it in the Settings."
                    } else {
                        self.speechSynthesisError = "Speech synthesis failed: \(error.localizedDescription)"
                    }
                    self.isSynthesizingAnswerSpeech = false
                }
            }
        }
    }

    // AVAudioPlayerDelegate method
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == audioPlayer {
            isSynthesizingSpeech = false
            isPlayingFirstChunk = false
            if !flag {
                speechSynthesisError = "Audio playback did not finish successfully."
            }
            audioPlayer = nil
            remainingAudioPlayer = nil
        } else if player == answerAudioPlayer {
            isSynthesizingAnswerSpeech = false
            if !flag {
                speechSynthesisError = "Answer audio playback did not finish successfully."
            }
            answerAudioPlayer = nil
        }
    }

    // MARK: - Local Text-to-Speech (uses built-in macOS voices)
    func speakSummaryLocally() {
        guard let summaryToSpeak = summary, !summaryToSpeak.isEmpty else {
            speechSynthesisError = "No summary available to read."
            return
        }

        // Stop remote audio if playing
        audioPlayer?.stop()
        remainingAudioPlayer?.stop()
        remainingAudioPlayer = nil
        isPlayingFirstChunk = false
        // Stop current local speech if any
        localSpeechSynth?.stopSpeaking()
        
        // Also stop any answer audio
        answerAudioPlayer?.stop()
        answerLocalSpeechSynth?.stopSpeaking()

        let synth = NSSpeechSynthesizer()
        synth.delegate = self
        // Optional: choose a voice – comment out to use system default
        // synth.setVoice(NSSpeechSynthesizer.VoiceName("com.apple.speech.synthesis.voice.Kate"))
        isSpeakingLocally = true
        if !synth.startSpeaking(summaryToSpeak) {
            isSpeakingLocally = false
            speechSynthesisError = "Failed to start local speech synthesis."
        } else {
            localSpeechSynth = synth
        }
    }

    func stopLocalSpeech() {
        localSpeechSynth?.stopSpeaking()
    }

    // NSSpeechSynthesizerDelegate
    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        if sender == localSpeechSynth {
            isSpeakingLocally = false
            if !finishedSpeaking {
                speechSynthesisError = "Local speech synthesis was interrupted."
            }
            localSpeechSynth = nil
        } else if sender == answerLocalSpeechSynth {
            isSpeakingAnswerLocally = false
            if !finishedSpeaking {
                speechSynthesisError = "Local answer speech synthesis was interrupted."
            }
            answerLocalSpeechSynth = nil
        }
    }

    // MARK: - Text-to-Speech for Answers
    
    func speakAnswerLocally(answer: String) {
        guard !answer.isEmpty else {
            speechSynthesisError = "No answer available to read."
            return
        }

        // Stop remote audio if playing
        answerAudioPlayer?.stop()
        // Stop current local speech if any
        answerLocalSpeechSynth?.stopSpeaking()
        
        // Also stop any summary audio
        audioPlayer?.stop()
        remainingAudioPlayer?.stop()
        remainingAudioPlayer = nil
        isPlayingFirstChunk = false
        localSpeechSynth?.stopSpeaking()

        let synth = NSSpeechSynthesizer()
        synth.delegate = self
        isSpeakingAnswerLocally = true
        if !synth.startSpeaking(answer) {
            isSpeakingAnswerLocally = false
            speechSynthesisError = "Failed to start local speech synthesis."
        } else {
            answerLocalSpeechSynth = synth
        }
    }
    
    func stopAnswerLocalSpeech() {
        answerLocalSpeechSynth?.stopSpeaking()
    }
}

// MARK: - UI Views

// New PostDetailView
struct PostDetailView: View {
    let post: PostData
    @Environment(\.openURL) var openURL
    @State private var imageLoadFailed = false
    @State private var imageLoadingTimedOut = false
    @ObservedObject var viewModel: RedditViewModel
    @State private var question: String = ""
    @State private var answer: String? = nil
    @State private var isAnswering: Bool = false
    @State private var answerError: String? = nil
    @FocusState private var isQuestionFieldFocused: Bool
    @AppStorage("glassVariant") private var glassVariant: Int = 11
    @State private var selectedImageURL: URL? = nil
    @State private var showingFullScreenImage = false
    
    var body: some View {
        ZStack {
            // Glass background for entire view
            LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 0) {
                Color.clear
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                // HEADER SECTION
                VStack(alignment: .leading, spacing: 8) {
                    // Title with better spacing and line limits
                    Text(post.title)
                        .font(.headline)
                        .lineLimit(nil) // Allow multiple lines
                        .fixedSize(horizontal: false, vertical: true) // Proper text wrapping
                        .padding(.horizontal)
                    
                    // Post metadata with better layout
                    HStack(spacing: 16) {
                        Text("u/\(post.author)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button(action: {
                            if let url = URL(string: "https://www.reddit.com/r/\(post.subreddit)") {
                                openURL(url)
                            }
                        }) {
                            Text("r/\(post.subreddit)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Post timing
                        Text(timeAgo(from: post.created_utc))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.top, 4)
                }
                
                // CONTENT SECTION
                Group {
                    if post.is_self {
                        // Show text post content if available
                        VStack(alignment: .leading, spacing: 8) {
                            if let selfText = post.selftext, !selfText.isEmpty {
                                // Actual text content
                                InteractiveTextView(text: selfText.decodeHTMLFormatted(), onImageTap: { url in
                                    selectedImageURL = url
                                    showingFullScreenImage = true
                                })
                                    .font(.body)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .background(
                                        LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                                            Color.clear
                                        }
                                    )
                                    .padding(.horizontal)
                            } else {
                                // Fallback for empty text
                                HStack {
                                    Spacer()
                                    VStack(spacing: 10) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 32))
                                            .foregroundColor(.secondary)
                                        Text("No text content available")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(height: 100)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Link/image/gallery post with better fallback handling
                        let galleryImageURL: URL? = { // Closure to determine gallery image
                            if post.is_gallery == true, let mediaMetadata = post.media_metadata, !mediaMetadata.isEmpty {
                                // Find the first valid image item in the gallery
                                for itemKey in mediaMetadata.keys.sorted() { // Iterate in a consistent order if needed
                                    if let mediaItem = mediaMetadata[itemKey],
                                       let urlString = mediaItem.displayURLString?.replacingOccurrences(of: "&amp;", with: "&"),
                                       let url = URL(string: urlString) {
                                        print("Found gallery image: \(url)")
                                        return url
                                    }
                                }
                            }
                            return nil
                        }()
                        
                        if let effectiveImageURL = galleryImageURL ?? (isLikelyImageURL(post.url) ? URL(string: post.url.replacingOccurrences(of: "&amp;", with: "&")) : nil) {
                            // We have an image to display (either from gallery or direct post URL)
                            ZStack {
                                if !imageLoadFailed && !imageLoadingTimedOut {
                                    PostImageView(url: effectiveImageURL, onFailure: { imageLoadFailed = true })
                                }
                                
                                if imageLoadFailed || imageLoadingTimedOut {
                                    ImageLoadErrorView(
                                        url: effectiveImageURL,
                                        isTimeout: imageLoadingTimedOut,
                                        onOpen: { openURL(effectiveImageURL) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        } else if isLikelyVideoURL(post.url),
                                  let postUrl = URL(string: post.url.replacingOccurrences(of: "&amp;", with: "&")) {
                            // Handle video posts with appropriate thumbnail
                            let thumbnailURL = post.displayThumbnailURL
                            
                            VideoThumbnailView(url: postUrl, thumbnailURL: thumbnailURL)
                                .padding(.horizontal)
                                
                        } else if let postUrl = URL(string: post.url) { // Not self, not image, not video, not gallery -> treat as other link
                            LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                                VStack(spacing: 12) {
                                HStack {
                                    Spacer()
                                    Image(systemName: getLinkIcon(for: post.url))
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                                
                                Text(getDisplayLink(for: post.url))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    openURL(postUrl)
                                } label: {
                                    Label("Open Link", systemImage: "arrow.up.forward.app")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                        }
                    }
                }
                
                // Reply to post button
                if RedditAuthManager.shared.isAuthenticated {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: {
                                if viewModel.replyingToId == "post_\(post.id)" {
                                    viewModel.replyingToId = nil
                                    viewModel.replyText = ""
                                } else {
                                    viewModel.replyingToId = "post_\(post.id)"
                                    viewModel.replyText = ""
                                }
                            }) {
                                Label("Reply to Post", systemImage: "arrowshape.turn.up.left")
                                    .font(.callout)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            
                            Spacer()
                        }
                        
                        // Reply input field for post
                        if viewModel.replyingToId == "post_\(post.id)" {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Replying as: \(RedditAuthManager.shared.username ?? "Unknown")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                TextField("Write a comment...", text: $viewModel.replyText, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...10)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Button("Cancel") {
                                        viewModel.replyingToId = nil
                                        viewModel.replyText = ""
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button("Post Comment") {
                                        Task {
                                            await postReplyToPost()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPostingReply)
                                }
                                .padding(.horizontal)
                                
                                if let error = viewModel.replyError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background(
                        LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                            Color.clear
                        }
                    )
                    .padding(.horizontal)
                }
                
                // POST STATS
                HStack(spacing: 20) {
                    Label("\(post.score)", systemImage: "arrow.up")
                        .foregroundColor(.orange)
                    
                    Label("\(post.num_comments)", systemImage: "bubble.left")
                        .foregroundColor(.blue)
                }
                .font(.callout)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // COMMENTS SECTION
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Comments")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: post.fullPermalink) {
                                openURL(url)
                            }
                        }) {
                            Label("View Post on Reddit", systemImage: "safari")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    // Comments section with loading state and error handling
                    if viewModel.isLoadingComments {
                        // Loading state
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading comments...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                    } else if let error = viewModel.commentError {
                        // Error state
                        LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.orange)
                                
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    viewModel.fetchComments(for: post)
                                } label: {
                                    Label("Retry", systemImage: "arrow.clockwise")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                    } else if viewModel.currentPostComments.isEmpty {
                        // No comments state
                        LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                            VStack(alignment: .center, spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                
                                Text("No comments yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    if let url = URL(string: post.fullPermalink) {
                                        openURL(url)
                                    }
                                } label: {
                                    Label("View Post on Reddit", systemImage: "safari")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                    } else {
                        // Comment Analysis Tools
                        LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 12) {
                            VStack(spacing: 8) {
                                HStack {
                                    Button(action: {
                                        viewModel.summarizeComments()
                                    }) {
                                        if viewModel.isSummarizing {
                                            ProgressView()
                                                .padding(.trailing, 5)
                                            Text("Summarizing...")
                                        } else {
                                            Label("Summarize Comments", systemImage: "text.redaction")
                                        }
                                    }
                                    .disabled(viewModel.isSummarizing)
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                if viewModel.commentsSentToLLMCount > 0 && (viewModel.isSummarizing || viewModel.summary != nil) {
                                    Text("Analyzed \(viewModel.commentsSentToLLMCount) comments")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            
                            if let summary = viewModel.summary {
                                ResizableTextBox(title: "Summary", content: summary)
                                    .padding(.horizontal)
                                
                                // TTS Button and status
                                HStack {
                                    Button(action: {
                                        if viewModel.isSynthesizingSpeech {
                                            viewModel.stopSpeech()
                                        } else {
                                            viewModel.speakSummary()
                                        }
                                    }) {
                                        if viewModel.isSynthesizingSpeech {
                                            ProgressView()
                                                .padding(.trailing, 5)
                                            Text("Stop Reading")
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "cloud.fill")
                                                    .font(.caption)
                                                Text("Read (Cloud)")
                                            }
                                        }
                                    }
                                    .disabled(viewModel.summary == nil || viewModel.summary!.isEmpty)
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)

                                    Menu {
                                        ForEach(OpenAIVoice.allCases, id: \.rawValue) { voice in
                                            Button(action: {
                                                OpenAIService.shared.currentVoice = voice
                                            }) {
                                                HStack {
                                                    Text(voice.displayName)
                                                    if OpenAIService.shared.currentVoice == voice {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        Label(OpenAIService.shared.currentVoice.displayName, systemImage: "person.wave.2")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(8)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)

                                    Button(action: {
                                        if viewModel.isSpeakingLocally {
                                            viewModel.stopLocalSpeech()
                                        } else {
                                            viewModel.speakSummaryLocally()
                                        }
                                    }) {
                                        if viewModel.isSpeakingLocally {
                                            HStack(spacing: 4) {
                                                Image(systemName: "stop.fill")
                                                    .font(.caption)
                                                Text("Stop Local")
                                            }
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "speaker.wave.2.fill")
                                                    .font(.caption)
                                                Text("Read (Local)")
                                            }
                                        }
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                    .disabled(viewModel.summary == nil || viewModel.summary!.isEmpty)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                                
                                // Progress bar for TTS synthesis
                                if viewModel.isSynthesizingSpeech && viewModel.speechSynthesisProgress > 0 {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ProgressView(value: viewModel.speechSynthesisProgress, total: 1.0)
                                            .progressViewStyle(LinearProgressViewStyle())
                                        Text("Synthesis Progress: \(Int(viewModel.speechSynthesisProgress * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Display speech synthesis error for summary
                                if let ttsError = viewModel.speechSynthesisError, 
                                   (viewModel.isSynthesizingSpeech || viewModel.isSpeakingLocally) {
                                    Text("Speech Error: \(ttsError)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal)
                                }
                                
                            } else if let summaryError = viewModel.summaryError {
                                Text("Summary Error: \(summaryError)")
                                    .foregroundColor(.red)
                                    .padding()
                            }
                            
                            // Comment Question Interface
                            if !viewModel.currentPostComments.isEmpty {
                                Divider().padding(.vertical, 4)
                                
                                VStack(alignment: .leading) {
                                    Text("Ask a question about these comments:")
                                        .font(.headline)
                                        .padding([.horizontal, .top])
                                    
                                    HStack {
                                        TextField("Enter your question", text: $question)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .focused($isQuestionFieldFocused)
                                            .onSubmit {
                                                isQuestionFieldFocused = false
                                                askQuestion()
                                            }
                                            .disabled(isAnswering)
                                        
                                        Button(action: {
                                            isQuestionFieldFocused = false
                                            askQuestion()
                                        }) {
                                            if isAnswering {
                                                ProgressView()
                                            } else {
                                                Text("Ask")
                                            }
                                        }
                                        .disabled(isAnswering || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                    .padding(.horizontal)
                                    
                                    if isAnswering {
                                        ProgressView("Answering...")
                                            .padding(.horizontal)
                                    } else if let answer = answer {
                                        ResizableTextBox(title: "Answer", content: answer)
                                            .padding(.horizontal)
                                            
                                        // Add TTS buttons for answer
                                        HStack {
                                            Button(action: {
                                                viewModel.speakAnswer(answer: answer)
                                            }) {
                                                if viewModel.isSynthesizingAnswerSpeech {
                                                    ProgressView()
                                                        .padding(.trailing, 5)
                                                    Text("Reading (Cloud)...")
                                                } else {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "cloud.fill")
                                                            .font(.caption)
                                                        Text("Read (Cloud)")
                                                    }
                                                }
                                            }
                                            .disabled(viewModel.isSynthesizingAnswerSpeech || answer.isEmpty)
                                            .buttonStyle(BorderlessButtonStyle())
                                            .padding(8)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)

                                            Menu {
                                                ForEach(OpenAIVoice.allCases, id: \.rawValue) { voice in
                                                    Button(action: {
                                                        OpenAIService.shared.currentVoice = voice
                                                    }) {
                                                        HStack {
                                                            Text(voice.displayName)
                                                            if OpenAIService.shared.currentVoice == voice {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                Label(OpenAIService.shared.currentVoice.displayName, systemImage: "person.wave.2")
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            .padding(8)
                                            .background(Color.purple.opacity(0.1))
                                            .cornerRadius(8)

                                            Button(action: {
                                                if viewModel.isSpeakingAnswerLocally {
                                                    viewModel.stopAnswerLocalSpeech()
                                                } else {
                                                    viewModel.speakAnswerLocally(answer: answer)
                                                }
                                            }) {
                                                if viewModel.isSpeakingAnswerLocally {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "stop.fill")
                                                            .font(.caption)
                                                        Text("Stop Local")
                                                    }
                                                } else {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "speaker.wave.2.fill")
                                                            .font(.caption)
                                                        Text("Read (Local)")
                                                    }
                                                }
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            .padding(8)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                            .disabled(answer.isEmpty)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        .padding(.top, 4)
                                        
                                        // Display speech synthesis error for answer
                                        if let ttsError = viewModel.speechSynthesisError, 
                                           (viewModel.isSynthesizingAnswerSpeech || viewModel.isSpeakingAnswerLocally) {
                                            Text("Speech Error: \(ttsError)")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .padding(.horizontal)
                                        }
                                    } else if let answerError = answerError {
                                        Text("Question Error: \(answerError)")
                                            .foregroundColor(.red)
                                            .padding(.horizontal)
                                    }
                                }
                                .padding(.bottom)
                                
                                if viewModel.commentsSentToLLMCount > 0 && (isAnswering || answer != nil) {
                                    Text("Sent \(viewModel.commentsSentToLLMCount) comments to LLM")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                }
                            }
                            }
                            .padding(.vertical)
                        }
                        .padding(.horizontal)
                        
                        // Comments list - render all top-level comments and their replies
                        // Comments list
                        VStack(spacing: 12) {
                            ForEach(viewModel.currentPostComments, id: \.id) { comment in
                                CommentView(comment: comment, post: post, viewModel: viewModel, onImageTap: { url in
                                    selectedImageURL = url
                                    showingFullScreenImage = true
                                })
                            }
                            
                            // Show loading indicator while fetching more comments
                            if viewModel.isLoadingMoreComments {
                                ProgressView()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("r/\(post.subreddit)")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let url = URL(string: "https://www.reddit.com/r/\(post.subreddit)") {
                        openURL(url)
                    }
                } label: {
                    Image(systemName: "rectangle.stack.fill")
                        .help("Open Subreddit")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let url = URL(string: post.fullPermalink) {
                        openURL(url)
                    }
                } label: {
                    Image(systemName: "safari")
                        .help("Open Post in Browser")
                }
            }
        }
        .onAppear {
            // Load comments when the view appears
            viewModel.fetchComments(for: post)
        }
        .sheet(isPresented: $showingFullScreenImage) {
            if let imageURL = selectedImageURL {
                FullScreenImageView(imageURL: imageURL, isPresented: $showingFullScreenImage)
                    #if os(iOS)
                    .interactiveDismissDisabled(false)
                    #else
                    .frame(minWidth: 600, minHeight: 800)
                    #endif
            }
        }
        }
    }
    
    private func askQuestion() {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Stop any ongoing TTS for previous answers
        viewModel.answerAudioPlayer?.stop()
        viewModel.stopAnswerLocalSpeech()
        
        isAnswering = true
        answer = nil
        answerError = nil
        
        Task {
            do {
                let result = try await viewModel.askQuestionAboutComments(question: question)
                DispatchQueue.main.async {
                    self.answer = result
                    self.isAnswering = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.answerError = error.localizedDescription
                    self.isAnswering = false
                }
            }
        }
    }
    
    // Helper function to format timestamps as relative time
    private func timeAgo(from timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper to check if URL likely points to an image or video
    private func isLikelyImageURL(_ urlString: String) -> Bool {
        let lowercasedUrlString = urlString.lowercased()

        // 1. Check common image extensions in the path itself
        if let url = URL(string: lowercasedUrlString) {
            let pathExtension = url.pathExtension
            let commonImageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"]
            if commonImageExtensions.contains(pathExtension) {
                // Further check for specific hosts if needed, or just return true
                if lowercasedUrlString.contains("i.redd.it/") || 
                   lowercasedUrlString.contains("preview.redd.it/") || 
                   lowercasedUrlString.contains("i.imgur.com/") || 
                   (url.host?.contains("reddit.com") != true) { // Corrected condition for non-Reddit hosts
                    return true
                }
            }
        }

        // 2. Check for Reddit specific patterns (i.redd.it or preview.redd.it with format params)
        if lowercasedUrlString.contains("i.redd.it/") {
            return true // i.redd.it are usually direct images
        }
        if lowercasedUrlString.contains("preview.redd.it/") {
            if lowercasedUrlString.contains("format=png") || 
               lowercasedUrlString.contains("format=jpg") || 
               lowercasedUrlString.contains("format=jpeg") || // Added format=jpeg
               lowercasedUrlString.contains("format=pjpg") || // Added format=pjpg
               lowercasedUrlString.contains("format=webp") {
                return true
            }
            // Also, if the path itself on preview.redd.it ends with an image extension, treat as image
            // This handles cases where format parameter might be missing or different but path is explicit
            if let url = URL(string: lowercasedUrlString), 
               ["jpg", "jpeg", "png", "gif"].contains(url.pathExtension) {
                return true
            }
        }

        // 3. Check Imgur direct images
        if lowercasedUrlString.contains("i.imgur.com/") {
            return true
        }

        // 4. Fallback for general URLs that might end with an image extension but weren't caught by host-specific logic
        // (This part is somewhat covered by step 1 but provides a broader catch)
        let imagePathExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]
        if imagePathExtensions.contains(where: { lowercasedUrlString.hasSuffix($0) }) {
             // To avoid overly broad matches (e.g. a webpage ending in .png), 
             // we could add a check here that it's not a common HTML page, but for now, this is fine for most image links.
            return true
        }

        return false
    }
    
    // Helper to check if URL likely points to a video
    private func isLikelyVideoURL(_ urlString: String) -> Bool {
        let url = urlString.lowercased()
        
        // Check common video extensions
        let videoExtensions = ["mp4", "mov", "avi", "wmv", "flv", "webm"]
        if videoExtensions.contains(where: { url.hasSuffix(".\($0)") }) {
            return true
        }
        
        // Reddit video hosts
        if url.contains("v.redd.it") {
            return true // Reddit video server
        }
        
        // YouTube
        if url.contains("youtube.com/watch") || url.contains("youtu.be/") {
            return true
        }
        
        // Streamable
        if url.contains("streamable.com") {
            return true
        }
        
        return false
    }
    
    // Helper to get appropriate icon for link type
    private func getLinkIcon(for urlString: String) -> String {
        let url = urlString.lowercased()
        
        // Video sites
        if url.contains("youtube.com") || url.contains("youtu.be") {
            return "play.rectangle"
        } else if url.contains("v.redd.it") {
            return "play.rectangle"
        } else if url.contains("streamable.com") {
            return "play.rectangle"
        } else if url.contains("vimeo.com") {
            return "play.rectangle"
        }
        
        // Social/news sites
        else if url.contains("twitter.com") || url.contains("x.com") {
            return "bubble.left"
        } else if url.contains("github.com") {
            return "terminal"
        } else if url.contains("apple.com") {
            return "apple.logo"
        } 
        
        // Video file extensions
        let videoExtensions = ["mp4", "mov", "avi", "webm"]
        if videoExtensions.contains(where: { url.hasSuffix(".\($0)") }) {
            return "play.rectangle"
        }
        
        // Default
        return "link"
    }
    
    // Helper to format link URL for display
    private func getDisplayLink(for urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        
        if let host = url.host {
            let displayPath = url.path.count > 15 ? String(url.path.prefix(15)) + "..." : url.path
            return host + (displayPath.isEmpty || displayPath == "/" ? "" : displayPath)
        }
        
        return urlString
    }
    
    private func postReplyToPost() async {
        let parentId = "t3_\(post.id)"
        viewModel.isPostingReply = true
        viewModel.replyError = nil
        
        do {
            let newComment = try await viewModel.postComment(parentId: parentId, text: viewModel.replyText)
            
            // Add the new comment to the comments list
            await MainActor.run {
                // Add to the beginning of comments since it's a new top-level comment
                viewModel.currentPostComments.insert(newComment, at: 0)
                
                // Clear reply state
                viewModel.replyingToId = nil
                viewModel.replyText = ""
                viewModel.isPostingReply = false
            }
        } catch {
            await MainActor.run {
                viewModel.replyError = "Failed to post comment: \(error.localizedDescription)"
                viewModel.isPostingReply = false
            }
        }
    }
}

// Comment view to display a single comment
struct CommentView: View {
    let comment: CommentData
    let post: PostData
    @ObservedObject var viewModel: RedditViewModel
    var onImageTap: ((URL) -> Void)?
    let indentationWidth: CGFloat = 15
    @AppStorage("glassVariant") private var glassVariant = 11
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Comment content
            VStack(alignment: .leading, spacing: 8) {
                // Comment header with author & metadata
                HStack {
                    Text(comment.author ?? "[deleted]")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Comment score
                    if let score = comment.score {
                        Label("\(score)", systemImage: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    // Comment date
                    if let created = comment.created_utc {
                        Text(timeAgo(from: created))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Comment body - always show
                if let body = comment.body, !body.isEmpty {
                    InteractiveTextView(text: body.decodeHTMLFormatted(), onImageTap: onImageTap)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("[deleted]")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Reply button (only show if authenticated and not deleted)
                if RedditAuthManager.shared.isAuthenticated && comment.author != "[deleted]" {
                    HStack {
                        Button(action: {
                            if viewModel.replyingToId == comment.id {
                                viewModel.replyingToId = nil
                                viewModel.replyText = ""
                            } else {
                                viewModel.replyingToId = comment.id
                                viewModel.replyText = ""
                            }
                        }) {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    // Reply input field
                    if viewModel.replyingToId == comment.id {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Replying as: \(RedditAuthManager.shared.username ?? "Unknown")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            TextField("Write a reply...", text: $viewModel.replyText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...10)
                            
                            HStack {
                                Button("Cancel") {
                                    viewModel.replyingToId = nil
                                    viewModel.replyText = ""
                                }
                                .buttonStyle(.plain)
                                
                                Button("Post Reply") {
                                    Task {
                                        await postReply()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPostingReply)
                            }
                            
                            if let error = viewModel.replyError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                    Color.clear
                }
            )
            // Add left padding for nested comments based on depth
            .padding(.leading, CGFloat(comment.depth) * indentationWidth)
            
            // "Load more comments" button (only if this is a "more" placeholder)
            if comment.moreCommentsAvailable, let count = comment.count, count > 0 {
                LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 6) {
                    Button {
                        viewModel.loadMoreComments(for: comment)
                    } label: {
                        HStack {
                            Image(systemName: "ellipsis.circle")
                            Text("Load \(count) more comment\(count == 1 ? "" : "s")")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
                .padding(.leading, CGFloat(comment.depth) * indentationWidth + 15)
            }
            
            // Show nested comments if any
            if !comment.nestedReplies.isEmpty {
                ForEach(comment.nestedReplies, id: \.id) { reply in
                    CommentView(comment: reply, post: post, viewModel: viewModel, onImageTap: onImageTap)
                }
            }
        }
    }
    
    private func postReply() async {
        let parentId = "t1_\(comment.id)"
        viewModel.isPostingReply = true
        viewModel.replyError = nil
        
        do {
            let newComment = try await viewModel.postComment(parentId: parentId, text: viewModel.replyText)
            
            // Add the new comment to the nested replies
            await MainActor.run {
                // Find and update the comment in the tree
                updateCommentWithReply(newComment, parentId: comment.id ?? "")
                
                // Clear reply state
                viewModel.replyingToId = nil
                viewModel.replyText = ""
                viewModel.isPostingReply = false
            }
        } catch {
            await MainActor.run {
                viewModel.replyError = "Failed to post reply: \(error.localizedDescription)"
                viewModel.isPostingReply = false
            }
        }
    }
    
    private func updateCommentWithReply(_ newComment: CommentData, parentId: String) {
        // This is a simplified version - in a real app you'd want to update the comment tree properly
        // For now, we'll just trigger a refresh of the comments
        viewModel.fetchComments(for: post)
    }
    
    // Helper function to format timestamps as relative time
    private func timeAgo(from timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Helper view to display post images
struct PostImageView: View {
    let url: URL
    var onFailure: () -> Void = {}
    @State private var isLoading = true // Keep for initial progress view, KingFisher will handle internal loading state
    @State private var showFullScreen = false

    var body: some View {
        let correctedURLString = url.absoluteString.replacingOccurrences(of: "&amp;", with: "&")
        let correctedURL = URL(string: correctedURLString) ?? url
        
        KFImage(correctedURL)
            .requestModifier(ImageDownloadRequestModifier(userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"))
            .placeholder { // Placeholder while loading or if it fails before onFailure is called by KF
                if isLoading {
                    ProgressView()
                        .onAppear {
                            // Optional: Set a timeout for the initial ProgressView if KF takes too long to start
                            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                                if isLoading { // If still loading after timeout
                                    print("Image loading (KF placeholder) timeout: " + String(describing: url))
                                    // onFailure() // Kingfisher's own onFailure should handle this better
                                }
                            }
                        }
                } else {
                    // This else branch might not be hit often if KF's onFailure is effective
                    Color.clear // Or a more specific error icon if needed
                }
            }
            .onSuccess { _ in
                isLoading = false
            }
            .onFailure { error in
                print("Kingfisher failed to load image: " + String(describing: url) + ", error: " + String(describing: error))
                isLoading = false
                onFailure()
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .cornerRadius(8)
            .clipped()
            .onTapGesture {
                showFullScreen = true
            }
            .sheet(isPresented: $showFullScreen) {
                FullScreenImageView(imageURL: correctedURL, isPresented: $showFullScreen)
                    #if os(iOS)
                    .interactiveDismissDisabled(false)
                    #else
                    .frame(minWidth: 600, minHeight: 800)
                    #endif
            }
            .onAppear {
                isLoading = true
                print("Kingfisher loading image: " + String(describing: url))
            }
            .onDisappear {
                isLoading = false // Reset if view disappears while loading
            }
    }
}

// Helper view for clickable images with full-screen support
struct ImageWithFullScreen: View {
    let url: URL
    var onTap: (URL) -> Void
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        KFImage(url)
            .placeholder {
                ProgressView()
                    .frame(height: 100)
            }
            .onFailure { _ in
                // Fall back to link on failure
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                onTap(url)
            }
    }
}

// Helper view for image loading errors
struct ImageLoadErrorView: View {
    let url: URL
    let isTimeout: Bool
    var onOpen: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.fill.on.rectangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text(isTimeout ? "Image loading timed out" : "Failed to load image")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                onOpen()
            } label: {
                Label("Open in Browser", systemImage: "safari")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct PostRowView: View {
    let post: PostData
    @State private var imageLoadFailed = false
    @State private var isExpanded = false
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Post title with better wrapping
            Text(post.title)
                .font(.headline)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true) // no clipping
            
            // Show post selftext for text posts
            if post.is_self, let selftext = post.selftext, !selftext.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selftext.decodeHTMLFormatted())
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 5) // Show 5 lines or full text
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    
                    // Show more/less button if text is long
                    if selftext.split(separator: "\n").count > 5 || selftext.count > 300 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Text(isExpanded ? "Show less" : "Show more")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            HStack(alignment: .top, spacing: 10) {
                // Extract thumbnail view to reduce complexity
                ThumbnailView(post: post)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Post metadata
                    Text("u/\(post.author) • r/\(post.subreddit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Post stats
                    HStack(spacing: 12) {
                        Label {
                            Text(formatNumber(post.score))
                        } icon: {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.orange)
                        }
                        .font(.caption)
                        
                        Label {
                            Text(formatNumber(post.num_comments))
                        } icon: {
                            Image(systemName: "bubble.left")
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                        
                        // Post age
                        Text(timeAgo(from: post.created_utc))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Link to Reddit - now using a cleaner button style
                    if let url = URL(string: post.fullPermalink) {
                        Button {
                            openURL(url)
                        } label: {
                            Text("Reddit")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Make the whole row tappable
    }
    
    // Helper function to format numbers (e.g., 1.2k instead of 1200)
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fm", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fk", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    // Helper function to format timestamps as relative time
    private func timeAgo(from timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Extracted thumbnail view
struct ThumbnailView: View {
    let post: PostData
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack {
            // Background for the image area
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.windowBackgroundColor))
                .frame(width: 60, height: 60)
            
            if let thumbnailUrl = post.displayThumbnailURL {
                KFImage(thumbnailUrl) // Initialize with just the URL
                    .requestModifier(ImageDownloadRequestModifier(userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"))
                    .placeholder { // Placeholder shown while loading or on failure
                        ProgressView()
                            .frame(width: 60, height: 60) // Ensure placeholder is same size
                    }
                    .onFailure { error in
                        print("Kingfisher failed to load thumbnail: " + String(describing: thumbnailUrl) + ", error: " + String(describing: error.localizedDescription))
                        // The placeholder below will be shown due to KFImage structure
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Add play button overlay for videos
                if isVideoPost(post) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 60, height: 60)
    }
    
    // Placeholder for missing or failed thumbnail images
    private var thumbnailPlaceholder: some View {
        Group {
            if post.is_self {
                Image(systemName: "doc.text")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            } else if isVideoPost(post) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            } else if post.over_18 == true {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            } else if post.spoiler == true {
                Image(systemName: "eye.slash")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 60, height: 60)
    }
    
    // Helper function to detect video posts
    private func isVideoPost(_ post: PostData) -> Bool {
        let url = post.url.lowercased()
        
        // Check common video extensions
        let videoExtensions = ["mp4", "mov", "avi", "wmv", "flv", "webm"]
        if videoExtensions.contains(where: { url.hasSuffix(".\($0)") }) {
            return true
        }
        
        // Reddit video hosts
        if url.contains("v.redd.it") {
            return true // Reddit video server
        }
        
        // YouTube
        if url.contains("youtube.com/watch") || url.contains("youtu.be/") {
            return true
        }
        
        // Streamable
        if url.contains("streamable.com") {
            return true
        }
        
        return false
    }
}

struct MenuContentView: View {
    @ObservedObject var viewModel: RedditViewModel
    @State private var colorScheme: ColorScheme = .light
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("glassVariant") private var glassVariant: Int = 11
    @State private var showingSettings = false
    var dismissAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Content Area with NavigationStack
            NavigationStack {
                VStack(spacing: 0) {
                    // Header with liquid glass effect - now inside NavigationStack
                    LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 0) {
                        VStack(spacing: 10) { // Controls Header
                            HStack {
                                TextField("r/", text: $viewModel.subreddit)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit { viewModel.fetchPosts() }
                                Button { viewModel.fetchPosts() } label: { Image(systemName: "arrow.clockwise.circle.fill") }
                                    .disabled(viewModel.isLoading || viewModel.isLoadingMore).help("Refresh posts")
                            }
                            // Custom glass-styled sort buttons
                            LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 8) {
                                HStack(spacing: 0) {
                                    ForEach(Array(SortType.allCases.enumerated()), id: \.element) { index, sortType in
                                        Button(action: {
                                            viewModel.currentSortType = sortType
                                            print("Selected sort type: \(sortType.rawValue)")
                                            viewModel.fetchPosts()
                                        }) {
                                            Text(sortType.rawValue.capitalized)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(viewModel.currentSortType == sortType ? .white : .secondary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 6)
                                                .background(
                                                    viewModel.currentSortType == sortType ?
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.accentColor.opacity(0.3))
                                                    : nil
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if index < SortType.allCases.count - 1 {
                                            Divider()
                                                .frame(height: 20)
                                        }
                                    }
                                }
                                .padding(4)
                            }
                        }
                        .padding()
                    }

                    // Content Area
                    LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 0) {
                        Group { // Use Group to handle conditional content
                        if viewModel.isLoading {
                            Spacer(); ProgressView("Loading r/\(viewModel.subreddit)..."); Spacer()
                        } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
                            Spacer(); Text(errorMessage).foregroundColor(.red).padding().multilineTextAlignment(.center); Spacer()
                        } else if viewModel.posts.isEmpty {
                            Spacer(); Text("No posts for r/\(viewModel.subreddit).").multilineTextAlignment(.center).padding(); Spacer()
                        } else {
                            List {
                            ForEach(viewModel.posts) { post in
                                NavigationLink {
                                    PostDetailView(post: post, viewModel: viewModel)
                                } label: {
                                    PostRowView(post: post)
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            }
                            if viewModel.afterToken != nil {
                                HStack {
                                    Spacer()
                                    if viewModel.isLoadingMore { ProgressView() } 
                                    else { Button("Load More") { viewModel.fetchPosts(isLoadingMore: true) } }
                                    Spacer()
                                }.padding(.vertical, 8)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                    }
                }
                        .background(Color.clear)
                        .toolbarBackground(.hidden, for: .windowToolbar)
                    }
                    
                    if let errorMessage = viewModel.errorMessage, !viewModel.posts.isEmpty { // Show errors below list if posts exist
                        Text(errorMessage).font(.caption).foregroundColor(.red)
                            .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                            .frame(maxWidth: .infinity, alignment: .leading).background(Color.yellow.opacity(0.2))
                    }
                    Divider()
                } // End VStack inside NavigationStack
            } // End NavigationStack
            
            // App Settings Footer
            LiquidGlassBackground(variant: GlassVariant(rawValue: glassVariant) ?? .v11, cornerRadius: 0) {
                VStack(spacing: 6) {
                HStack {
                    // Dark Mode Toggle
                    Toggle(isOn: $isDarkMode) {
                        Label("Dark Mode", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                            .font(.caption)
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .padding(.trailing)
                    .onChange(of: isDarkMode) { _ in
                        NSApp.appearance = isDarkMode ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 8)
                
                HStack {
                    Text("Reddit Menu Bar Reader").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Button("Settings") {
                        showingSettings = true
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(EdgeInsets(top: 4, leading: 15, bottom: 8, trailing: 15))
                }
            }
        }
        .popover(isPresented: $showingSettings, arrowEdge: .trailing) {
            SettingsView(isPresented: $showingSettings)
        }
        .onChange(of: viewModel.shouldShowSettingsForGeminiKey) { newValue in
            if newValue {
                showingSettings = true
                viewModel.shouldShowSettingsForGeminiKey = false
            }
        }
        .onAppear {
            // Load posts if they're empty
            if viewModel.posts.isEmpty && viewModel.errorMessage == nil { 
                viewModel.fetchPosts() 
            }
            
            // Set initial appearance during onAppear
            DispatchQueue.main.async {
                NSApp.appearance = isDarkMode ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light) // Set color scheme for SwiftUI components
        .background(
            // Invisible button that captures escape key
            Button("") {
                dismissAction?()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
        )
    }
}


// MARK: - App Delegate for NSStatusItem Management
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private let viewModel = RedditViewModel()
    
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        updateAppearance()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Try to use custom icon first, fallback to system icon
            if let customIcon = NSImage(named: customMenuBarIconName) {
                button.image = customIcon
            } else {
                button.image = NSImage(systemSymbolName: "list.bullet.rectangle.portrait.fill", accessibilityDescription: "RedbarApp")
            }
            
            button.action = #selector(togglePanel)
            button.target = self
        }
    }
    
    private func setupPanel() {
        let panelRect = NSRect(x: 0, y: 0, width: 400, height: 800)
        
        panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        panel?.title = "RedbarApp"
        panel?.level = .floating  // Always on top
        panel?.hidesOnDeactivate = false
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel?.isReleasedWhenClosed = false
        panel?.minSize = NSSize(width: 400, height: 400)
        panel?.maxSize = NSSize(width: 600, height: 1200)
        
        // Configure panel for transparency to support glass effects
        panel?.backgroundColor = .clear
        panel?.isOpaque = false
        panel?.hasShadow = true
        
        // Set up SwiftUI content
        let contentView = MenuContentView(viewModel: viewModel, dismissAction: { [weak self] in
            self?.panel?.orderOut(nil)
        })
            .frame(width: 400, height: 800)
            .environmentObject(viewModel)
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = CGColor.clear
        panel?.contentView = hostingView
    }
    
    private func updateAppearance() {
        NSApp.appearance = isDarkMode ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
    }
    
    @objc private func togglePanel() {
        guard let panel = panel else { return }
        
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            // Activate the app to ensure it can receive events
            NSApp.activate(ignoringOtherApps: true)
            
            // Position panel relative to status item
            if let button = statusItem?.button {
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = button.window?.convertToScreen(buttonRect) ?? buttonRect
                
                let panelRect = NSRect(
                    x: screenRect.midX - 200, // Center horizontally
                    y: screenRect.minY - 810, // Position below status item (adjusted for new height)
                    width: 400,
                    height: 800
                )
                
                panel.setFrame(panelRect, display: true)
            }
            
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Application Definition
@main
struct MyRedditMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - all functionality handled by AppDelegate
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Previews
#if DEBUG
struct MenuContentView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = RedditViewModel()
        mockViewModel.subreddit = "swiftui"
        mockViewModel.posts = [
            PostData(id: "1", title: "Exciting SwiftUI News & Updates - A Very Long Title to Test Line Limits and Wrapping Behavior", author: "swiftdev", subreddit: "swiftui", score: 1234, num_comments: 152, permalink: "/r/swiftui/comments/1/test", url: "https://apple.com", thumbnail: "https://external-preview.redd.it/D06-BRm81OZwQ1zBo5HcjHCt0qReaGzLReqc4u-R0LY.jpeg?width=140&amp;height=140,smart&amp;auto=webp&amp;s=d8ef6a41bf5faaf1760e09b7702347745b4a34c3", created_utc: Date().timeIntervalSince1970, is_self: true, spoiler: false, over_18: false, selftext: "This is a sample text post content. It can contain multiple paragraphs and explain the details of the post.\n\nSwiftUI is a great framework for building user interfaces across all Apple platforms. &gt; This is a quote.", is_gallery: false, media_metadata: nil),
            PostData(id: "2", title: "Cool Kingfisher Example for macOS", author: "maccoder", subreddit: "mac", score: 88, num_comments: 12, permalink: "/r/mac/comments/2/test2", url: "https://picsum.photos/200", thumbnail: "https://picsum.photos/id/237/60/60", created_utc: Date().timeIntervalSince1970, is_self: false, spoiler: false, over_18: false, selftext: nil, is_gallery: false, media_metadata: nil),
            PostData(id: "gallerypost1", title: "A Beautiful Gallery Post", author: "galleryfan", subreddit: "pics", score: 777, num_comments: 77, permalink: "/r/pics/comments/gallery1/test_gallery", url: "https://www.reddit.com/gallery/1khbq0", thumbnail: "self", created_utc: Date().timeIntervalSince1970 - 7200, is_self: false, spoiler: false, over_18: false, selftext: nil, 
                     is_gallery: true, 
                     media_metadata: [
                        "item1": MediaMetadataValue(id: "media1", status: "valid", e: "Image", m: "image/jpeg", p: [MediaItemPreview(u: "https://preview.redd.it/someimage1_low.jpg?width=108&crop=smart&auto=webp&s=1", x: 108, y: 72)], s: MediaItemSource(u: "https://preview.redd.it/someimage1.jpg?auto=webp&s=ABC", gif: nil, mp4: nil, x: 1920, y: 1080)),
                        "item2": MediaMetadataValue(id: "media2", status: "valid", e: "Image", m: "image/png", p: [MediaItemPreview(u: "https://preview.redd.it/someimage2_low.png?width=108&crop=smart&auto=webp&s=2", x: 108, y: 72)], s: MediaItemSource(u: "https://preview.redd.it/someimage2.png?auto=webp&s=DEF", gif: nil, mp4: nil, x: 1080, y: 1920))
                     ]
            )
        ]
        mockViewModel.favoriteSubreddits = ["swift", "macos", "iosprogramming"]
        return MenuContentView(viewModel: mockViewModel)
            .frame(width: 400, height: 800)
    }
}

struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock view model for preview
        let mockViewModel = RedditViewModel()
        
        // Add some mock comments to avoid API calls in preview
        mockViewModel.currentPostComments = [
            CommentData(
                id: "comment1", 
                author: "CommentUser1", 
                body: "This is a test comment that might be somewhat lengthy to demonstrate how text wrapping works in the comment view. What do you think about this post?", 
                score: 42, 
                created_utc: Date().timeIntervalSince1970 - 3600, 
                replies: nil
            ),
            CommentData(
                id: "comment2", 
                author: "AnotherUser", 
                body: "Great post, thanks for sharing!", 
                score: 12, 
                created_utc: Date().timeIntervalSince1970 - 7200, 
                replies: nil
            )
        ]
        
        // Create sample posts with selftext
        let sampleImagePost = PostData(
            id: "detail_preview_1",
            title: "This is a Detailed Post Title About Something Interesting and Visually Appealing",
            author: "DetailAuthor",
            subreddit: "swiftui_previews",
            score: 999,
            num_comments: 123,
            permalink: "/r/swiftui_previews/comments/xyz/sample_image_post/",
            url: "https://images.unsplash.com/photo-1579546929518-9e396f3cc809", // Example direct image URL
            thumbnail: "https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=60&h=60",
            created_utc: Date().timeIntervalSince1970 - 3600, // 1 hour ago
            is_self: false,
            spoiler: false,
            over_18: false,
            selftext: nil,
            is_gallery: false,
            media_metadata: nil
        )
        
        let sampleLinkPost = PostData(
            id: "detail_preview_3",
            title: "Interesting Article about Swift Concurrency",
            author: "ArticleWriter",
            subreddit: "swift",
            score: 450,
            num_comments: 67,
            permalink: "/r/swift/comments/abc/swift_concurrency_deep_dive/",
            url: "https://www.avanderlee.com/swift/concurrency/", // Example article URL
            thumbnail: "https://www.avanderlee.com/wp-content/uploads/2021/05/swift-ロゴ.png", // A relevant thumbnail
            created_utc: Date().timeIntervalSince1970 - (3600 * 5), // 5 hours ago
            is_self: false,
            spoiler: false,
            over_18: false,
            selftext: nil,
            is_gallery: false,
            media_metadata: nil
        )

        let sampleSelfPost = PostData(
            id: "detail_preview_2",
            title: "This is a Self Post (Text Post) Discussing Various Topics and Ideas",
            author: "SelfPostAuthor",
            subreddit: "selfpost_previews",
            score: 50,
            num_comments: 25,
            permalink: "/r/selfpost_previews/comments/abc/another_post/",
            url: "/r/selfpost_previews/comments/abc/another_post/", // Self posts often have relative URLs
            thumbnail: "self",
            created_utc: Date().timeIntervalSince1970 - (3600*24*2), // 2 days ago
            is_self: true,
            spoiler: false,
            over_18: false,
            selftext: "This is the content of a text post (self post) on Reddit. It can contain multiple paragraphs and formatting.\n\nText posts are useful for discussions, questions, and sharing thoughts without requiring external links or images.\n\n## This is a heading\n\n* Bullet point 1\n* Bullet point 2\n\nThank you for reading!",
            is_gallery: false,
            media_metadata: nil
        )

        return Group {
            NavigationStack {
                PostDetailView(post: sampleImagePost, viewModel: mockViewModel)
            }
            .previewDisplayName("Image Post Detail")
            .frame(width: 400, height: 700) // Give more height for detail view

            NavigationStack {
                PostDetailView(post: sampleLinkPost, viewModel: mockViewModel)
            }
            .previewDisplayName("Link Post Detail")
            .frame(width: 400, height: 700)

            NavigationStack {
                PostDetailView(post: sampleSelfPost, viewModel: mockViewModel)
            }
            .previewDisplayName("Self Post Detail")
            .frame(width: 400, height: 700)
        }
    }
}
#endif

// Helper struct for Kingfisher Request Modifier
struct ImageDownloadRequestModifier: Kingfisher.ImageDownloadRequestModifier {
    let userAgent: String

    func modified(for request: URLRequest) -> URLRequest? {
        var mutableRequest = request
        mutableRequest.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        return mutableRequest
    }
}

// Custom view to render text with interactive links and inline images
struct InteractiveTextView: View {
    let text: String
    var onImageTap: ((URL) -> Void)?
    @Environment(\.font) var font: Font?
    @Environment(\.openURL) var openURL
    
    struct Segment: Identifiable {
        enum SegmentType {
            case plainText
            case link(URL)
            case image(URL)
        }
        
        let id = UUID()
        let text: String
        let type: SegmentType
    }
    
    var body: some View {
        // Step 1: Preprocess Giphy markdown to replace with links
        let processedText = preprocessGiphyMarkdown(text.decodeHTMLFormatted())
        
        // Step 2: Parse content into segments
        let segments = parseContent(processedText)
        
        // Step 3: Render segments
        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments) { segment in
                switch segment.type {
                case .plainText:
                    Text(segment.text)
                        .font(font)
                        .fixedSize(horizontal: false, vertical: true)
                
                case .link(let url):
                    Link(destination: url) {
                        Text(segment.text)
                            .font(font)
                            .foregroundColor(.blue)
                            .underline()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                case .image(let url):
                    VStack(alignment: .leading, spacing: 4) {
                        ImageWithFullScreen(url: url, onTap: { imageURL in
                            onImageTap?(imageURL)
                        })
                            .frame(maxHeight: 200)
                        
                        Text(segment.text)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // Simplified Giphy preprocessing
    private func preprocessGiphyMarkdown(_ inputText: String) -> String {
        // Ultra-simplified Giphy syntax finder without complex regex
        // Looking for pattern like: ![gif](giphy|ID) or ![gif](giphy|ID|variant)
        
        // 1. Split the string into components
        let components = inputText.components(separatedBy: "![gif](giphy|")
        
        // If no split occurred or just one component, no Giphy syntax found
        if components.count <= 1 {
            return inputText
        }
        
        var result = components[0] // Start with text before first Giphy
        
        // Process each component after a Giphy marker
        for i in 1..<components.count {
            let component = components[i]
            
            // Find the closing parenthesis
            if let closingParenIndex = component.firstIndex(of: ")") {
                // Extract the Giphy ID
                let giphyPart = component[..<closingParenIndex]
                
                // Check if it has a variant (contains a pipe)
                var giphyID = String(giphyPart)
                if let pipeIndex = giphyPart.firstIndex(of: "|") {
                    giphyID = String(giphyPart[..<pipeIndex])
                }
                
                // Create the Markdown link
                let giphyLink = "[GIPHY: " + giphyID + "](https://giphy.com/gifs/" + giphyID + ")"
                
                // Append the replacement and the rest of the component
                result += giphyLink + component[component.index(after: closingParenIndex)...]
            } else {
                // No closing parenthesis found, just append the component as is
                result += "![gif](giphy|" + component
            }
        }
        
        return result
    }
    
    // Parse content into segments (plain text, links, images)
    private func parseContent(_ inputText: String) -> [Segment] {
        var segments: [Segment] = []
        
        // Use NSDataDetector to find links
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            // If detector creation fails, return the whole text as plain
            return [Segment(text: inputText, type: .plainText)]
        }
        
        let nsString = inputText as NSString
        let matches = detector.matches(in: inputText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // If no links detected, return the entire text as plain
        if matches.isEmpty {
            return [Segment(text: inputText, type: .plainText)]
        }
        
        // Process each match and text between matches
        var currentIndex = 0
        
        for match in matches {
            // Add text before the link
            if match.range.location > currentIndex {
                let range = NSRange(location: currentIndex, length: match.range.location - currentIndex)
                let beforeText = nsString.substring(with: range)
                if !beforeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(Segment(text: beforeText, type: .plainText))
                }
            }
            
            // Process the link
            if let url = match.url {
                let linkText = nsString.substring(with: match.range)
                
                // Check if it's an image URL
                if isImageURL(url.absoluteString) {
                    segments.append(Segment(text: linkText, type: .image(url)))
                } else {
                    segments.append(Segment(text: linkText, type: .link(url)))
                }
            }
            
            currentIndex = match.range.location + match.range.length
        }
        
        // Add remaining text after the last link
        if currentIndex < nsString.length {
            let range = NSRange(location: currentIndex, length: nsString.length - currentIndex)
            let afterText = nsString.substring(with: range)
            if !afterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(Segment(text: afterText, type: .plainText))
            }
        }
        
        return segments
    }
    
    // Helper to determine if a URL is an image
    private func isImageURL(_ urlString: String) -> Bool {
        let lowercasedUrlString = urlString.lowercased()

        // 1. Check common image extensions in the path itself
        if let url = URL(string: lowercasedUrlString) {
            let pathExtension = url.pathExtension
            let commonImageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"]
            if commonImageExtensions.contains(pathExtension) {
                // Further check for specific hosts if needed, or just return true
                if lowercasedUrlString.contains("i.redd.it/") || 
                   lowercasedUrlString.contains("preview.redd.it/") || 
                   lowercasedUrlString.contains("i.imgur.com/") || 
                   (url.host?.contains("reddit.com") != true) { // Corrected condition for non-Reddit hosts
                    return true
                }
            }
        }

        // 2. Check for Reddit specific patterns (i.redd.it or preview.redd.it with format params)
        if lowercasedUrlString.contains("i.redd.it/") {
            return true // i.redd.it are usually direct images
        }
        if lowercasedUrlString.contains("preview.redd.it/") {
            if lowercasedUrlString.contains("format=png") || 
               lowercasedUrlString.contains("format=jpg") || 
               lowercasedUrlString.contains("format=jpeg") || // Added format=jpeg
               lowercasedUrlString.contains("format=pjpg") || // Added format=pjpg
               lowercasedUrlString.contains("format=webp") {
                return true
            }
            // Also, if the path itself on preview.redd.it ends with an image extension, treat as image
            // This handles cases where format parameter might be missing or different but path is explicit
            if let url = URL(string: lowercasedUrlString), 
               ["jpg", "jpeg", "png", "gif"].contains(url.pathExtension) {
                return true
            }
        }

        // 3. Check Imgur direct images
        if lowercasedUrlString.contains("i.imgur.com/") {
            return true
        }

        // 4. Fallback for general URLs that might end with an image extension but weren't caught by host-specific logic
        // (This part is somewhat covered by step 1 but provides a broader catch)
        let imagePathExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]
        if imagePathExtensions.contains(where: { lowercasedUrlString.hasSuffix($0) }) {
             // To avoid overly broad matches (e.g. a webpage ending in .png), 
             // we could add a check here that it's not a common HTML page, but for now, this is fine for most image links.
            return true
        }

        return false
    }
}

// String extension for HTML decoding
extension String {
    func decodeHTMLFormatted() -> String {
        var result = self
        // Basic HTML entities. For a more comprehensive list, a library or more extensive map is needed.
        let htmlEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ", // Non-breaking space
            // Add more common entities if needed
        ]
        
        for (key, value) in htmlEntities {
            result = result.replacingOccurrences(of: key, with: value)
        }
        
        // Handle numeric entities (e.g., &#39;)
        // This is a simplified version. A full parser would be more robust.
        if let regex = try? NSRegularExpression(pattern: "&#([0-9]+);", options: .caseInsensitive) {
            let nsString = result as NSString 
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() { // Iterate backwards to avoid range issues
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: result) {
                    let numberString = String(result[swiftRange])
                    if let number = Int(numberString), let scalar = UnicodeScalar(number) {
                        let char = String(scalar)
                        result.replaceSubrange(Range(match.range, in: result)!, with: char)
                    }
                }
            }
        }
        
        return result
    }
}

// Helper view for video thumbnails with play button overlay
struct VideoThumbnailView: View {
    let url: URL
    let thumbnailURL: URL?
    @Environment(\.openURL) var openURL
    @State private var thumbnailLoadFailed = false
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
            
            // Video thumbnail (if available)
            if let thumbnailURL = thumbnailURL {
                KFImage(thumbnailURL)
                    .requestModifier(ImageDownloadRequestModifier(userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"))
                    .placeholder {
                        // Show loading indicator while thumbnail loads
                        ProgressView()
                    }
                    .onFailure { _ in 
                        thumbnailLoadFailed = true
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                // Video icon if no thumbnail
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.blue)
                    Text(getVideoSourceName(from: url.absoluteString))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
            }
            
            // Play button overlay
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            // Error overlay if thumbnail failed to load
            if thumbnailLoadFailed && thumbnailURL != nil {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                    
                    Text("Video from \(getVideoSourceName(from: url.absoluteString))")
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .padding(.trailing, 12)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            openURL(url)
        }
    }
    
    // Helper to get a display name for the video source
    private func getVideoSourceName(from urlString: String) -> String {
        let url = urlString.lowercased()
        
        if url.contains("youtube.com") || url.contains("youtu.be") {
            return "YouTube"
        } else if url.contains("v.redd.it") {
            return "Reddit"
        } else if url.contains("streamable.com") {
            return "Streamable"
        } else if url.contains("vimeo.com") {
            return "Vimeo"
        } else {
            return "Video"
        }
    }
}

// MARK: - Gemini Service
class GeminiService {
    static let shared = GeminiService()
    private let keychain = KeychainService.shared

    private init() { }

    func summarize(text: String) async throws -> String {
        guard let apiKey = keychain.geminiAPIKey, !apiKey.isEmpty else {
            print("GeminiService - Error: API key is missing.")
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API key is missing. Please set your Gemini API key in Settings."])
        }
        
        // Debug: Check API key format
        print("GeminiService - Debug: API key starts with: \(String(apiKey.prefix(8)))...")
        print("GeminiService - Debug: API key length: \(apiKey.count)")
        
        // URL encode the API key to handle special characters
        guard let encodedApiKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("GeminiService - Error: Failed to encode API key.")
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode API key."])
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(encodedApiKey)") else {
            print("GeminiService - Error: Invalid API URL.")
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Construct the request body with thinking disabled
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "thinkingConfig": [
                    "thinkingBudget": 0  // Disable thinking mode for faster response
                ]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            print("GeminiService - Error: Failed to serialize request body.")
            throw NSError(domain: "GeminiService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body."])
        }
        request.httpBody = httpBody

        // Log the request body for debugging
        print("GeminiService - Debug: Request body: \(String(data: httpBody, encoding: .utf8) ?? "Invalid body")")

        print("GeminiService - Info: Calling API URL: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("GeminiService - Error: Invalid HTTP response.")
            throw NSError(domain: "GeminiService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response."])
        }

        // Log status code and response body for debugging
        print("GeminiService - Debug: Response status code: \(httpResponse.statusCode)")
        let responseString = String(data: data, encoding: .utf8) ?? "[Could not decode response body]"
        print("GeminiService - Debug: Response body: \(responseString)")

        guard (200...299).contains(httpResponse.statusCode) else {
            print("GeminiService - Error: API request failed with status \(httpResponse.statusCode). Response: \(responseString)")
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API request failed with status \(httpResponse.statusCode). Response: \(responseString)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            print("GeminiService - Error: Failed to parse JSON response.")
            throw NSError(domain: "GeminiService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response."])
        }

        // Navigate through the expected JSON structure to find the text
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let generatedText = firstPart["text"] as? String else {
            print("GeminiService - Error: Could not extract generated text from response structure. Full JSON: \(json)")
            throw NSError(domain: "GeminiService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not extract generated text from response structure."])
        }

        print("GeminiService - Info: Successfully summarized text.")
        return generatedText
    }

    // TTS functionality has been moved to OpenAIService
}

// MARK: - ResizableTextBox Component
struct ResizableTextBox: View {
    let title: String
    let content: String
    @State private var boxHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    copyToClipboard(content)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(PlainButtonStyle())
                .help("Copy content")
            }

            ScrollView {
                Text(content)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: boxHeight)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                        .opacity(0.7)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                }
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)

            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 4)
                    .cornerRadius(2)
                Spacer()
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { gesture in
                        boxHeight = max(100, min(600, boxHeight + gesture.translation.height))
                    }
            )
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}



