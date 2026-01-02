import Foundation

class NetworkManager {
    // Singleton - One shared instance for the whole app
    static let shared = NetworkManager()
    
    // Base URL for the Django backend
    // private let baseURL = "https://episcopally-jennifer-preaccessible.ngrok-free.dev"
   private let baseURL = "http://127.0.0.1:8000"
    
    
    private init() {}
    
    func fetchPosts() async throws -> [Post] {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/posts/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create request with ngrok headers if needed
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // ngrok-free.dev may require this header
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        
        // 3. Fetch Data (Network Call)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 4. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        }
        
        // 5. Decode JSON into Swift Objects
        let decoder = JSONDecoder()
        let posts = try decoder.decode([Post].self, from: data)
        
        // 6. Fix relative URLs in media files
        let fixedPosts = posts.map { post -> Post in
            let fixedMedia = post.media.map { media -> PostMedia in
                if let fileUrl = media.fileUrl, fileUrl.hasPrefix("/") {
                    // Prepend base URL to relative URLs
                    return PostMedia(
                        id: media.id,
                        fileUrl: "\(baseURL)\(fileUrl)",
                        mediaType: media.mediaType,
                        order: media.order
                    )
                }
                return media
            }
            
            return Post(
                id: post.id,
                creator: post.creator,
                creatorUsername: post.creatorUsername,
                caption: post.caption,
                createdAt: post.createdAt,
                isForSale: post.isForSale,
                saleItem: post.saleItem,
                media: fixedMedia
            )
        }
        
        return fixedPosts
    }
}

