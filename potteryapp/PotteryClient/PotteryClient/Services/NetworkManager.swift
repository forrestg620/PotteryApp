import Foundation
import UIKit
import Combine

class NetworkManager: ObservableObject {
    // Singleton - One shared instance for the whole app
    static let shared = NetworkManager()
    
    // Base URL for the Django backend
    //  private let baseURL = "https://episcopally-jennifer-preaccessible.ngrok-free.dev"
    private let baseURL = "http://127.0.0.1:8000"
    
    // UserDefaults key for auth token
    private let authTokenKey = "authToken"
    
    // Auth token for API requests - saved to/read from UserDefaults
    private var authToken: String? {
        get {
            UserDefaults.standard.string(forKey: authTokenKey)
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: authTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: authTokenKey)
            }
        }
    }
    
    // Published property to track authentication status
    @Published var isAuthenticated = false
    
    private init() {
        // Check if auth token exists on initialization
        if authToken != nil {
            isAuthenticated = true
        }
    }
    
    func setAuthToken(_ token: String?) {
        authToken = token
        isAuthenticated = token != nil
    }
    
    // Helper method to add Authorization header to requests
    private func addAuthHeader(to request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    // MARK: - Authentication
    
    func login(username: String, password: String) async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api-token-auth/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create JSON body
        let body: [String: String] = ["username": username, "password": password]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        // 3. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.httpBody = jsonData
        
        // 4. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 5. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Login error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Login failed: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 6. Decode JSON response to extract token
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw NSError(domain: "NetworkError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode token from response"
            ])
        }
        
        // 7. Save token and update authentication status
        self.authToken = token
        self.isAuthenticated = true
    }
    
    func signOut() {
        // Clear token (this also removes it from UserDefaults via the setter)
        authToken = nil
        isAuthenticated = false
    }
    
    // MARK: - API Methods
    
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
        addAuthHeader(to: &request)
        
        // 3. Fetch Data (Network Call)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 4. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 5. Decode JSON into Swift Objects
        let decoder = JSONDecoder()
        let posts = try decoder.decode([Post].self, from: data)
        
        // 6. Fix relative URLs in media files and thumbnails
        let fixedPosts = posts.map { post -> Post in
            let fixedMedia = post.media.map { media -> PostMedia in
                var fixedFileUrl = media.fileUrl
                var fixedThumbnailUrl = media.thumbnailUrl
                
                // Fix file URL if it's relative
                if let fileUrl = media.fileUrl, fileUrl.hasPrefix("/") {
                    fixedFileUrl = "\(baseURL)\(fileUrl)"
                }
                
                // Fix thumbnail URL if it's relative
                if let thumbnailUrl = media.thumbnailUrl, thumbnailUrl.hasPrefix("/") {
                    fixedThumbnailUrl = "\(baseURL)\(thumbnailUrl)"
                }
                
                return PostMedia(
                    id: media.id,
                    fileUrl: fixedFileUrl,
                    thumbnailUrl: fixedThumbnailUrl,
                    mediaType: media.mediaType,
                    order: media.order
                )
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
    
    func fetchMyPosts() async throws -> [Post] {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/posts/my_posts/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create request with ngrok headers if needed
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // ngrok-free.dev may require this header
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        
        // 3. Fetch Data (Network Call)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 4. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 5. Decode JSON into Swift Objects
        let decoder = JSONDecoder()
        let posts = try decoder.decode([Post].self, from: data)
        
        // 6. Fix relative URLs in media files and thumbnails
        let fixedPosts = posts.map { post -> Post in
            let fixedMedia = post.media.map { media -> PostMedia in
                var fixedFileUrl = media.fileUrl
                var fixedThumbnailUrl = media.thumbnailUrl
                
                // Fix file URL if it's relative
                if let fileUrl = media.fileUrl, fileUrl.hasPrefix("/") {
                    fixedFileUrl = "\(baseURL)\(fileUrl)"
                }
                
                // Fix thumbnail URL if it's relative
                if let thumbnailUrl = media.thumbnailUrl, thumbnailUrl.hasPrefix("/") {
                    fixedThumbnailUrl = "\(baseURL)\(thumbnailUrl)"
                }
                
                return PostMedia(
                    id: media.id,
                    fileUrl: fixedFileUrl,
                    thumbnailUrl: fixedThumbnailUrl,
                    mediaType: media.mediaType,
                    order: media.order
                )
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
    
    func uploadPost(image: UIImage, caption: String) async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/posts/") else {
            throw URLError(.badURL)
        }
        
        // 2. Generate unique boundary
        let boundary = UUID().uuidString
        
        // 3. Convert UIImage to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        // 4. Create multipart/form-data body
        var body = Data()
        
        // Append caption field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
        body.append(caption.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Append image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 5. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        request.httpBody = body
        
        // 6. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 7. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // Optional: You might want to decode and return the created Post
        // For now, we just verify the upload succeeded
    }
    
    func uploadPostWithVideo(videoURL: URL, caption: String) async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/posts/") else {
            throw URLError(.badURL)
        }
        
        // 2. Generate unique boundary
        let boundary = UUID().uuidString
        
        // 3. Read video file data
        let videoData: Data
        do {
            videoData = try Data(contentsOf: videoURL)
        } catch {
            throw NSError(domain: "NetworkError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read video file: \(error.localizedDescription)"
            ])
        }
        
        // 4. Get file extension and MIME type
        let fileExtension = videoURL.pathExtension.lowercased()
        let mimeType: String
        let filename: String
        
        switch fileExtension {
        case "mov":
            mimeType = "video/quicktime"
            filename = "upload.mov"
        case "mp4":
            mimeType = "video/mp4"
            filename = "upload.mp4"
        default:
            mimeType = "video/mp4"
            filename = "upload.\(fileExtension)"
        }
        
        // 5. Create multipart/form-data body
        var body = Data()
        
        // Append caption field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
        body.append(caption.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Append video field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 6. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        request.httpBody = body
        
        // 7. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 8. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
    }
    
    func convertPostToShelf(postId: Int, price: Double) async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/posts/\(postId)/convert_to_shelf/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create JSON body
        let body: [String: Double] = ["price": price]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        // 3. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        request.httpBody = jsonData
        
        // 5. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 6. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
    }
    
    func createPaymentIntent(postId: Int) async throws -> String {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/create-payment-intent/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create JSON body
        let body: [String: Int] = ["post_id": postId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        // 3. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        request.httpBody = jsonData
        
        // 5. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 6. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 7. Decode JSON response to extract client_secret
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clientSecret = json["client_secret"] as? String else {
            throw NSError(domain: "NetworkError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode client_secret from response"
            ])
        }
        
        return clientSecret
    }
    
    func markItemAsSold(postId: Int) async throws -> Post {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/mark-item-as-sold/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create JSON body
        let body: [String: Int] = ["post_id": postId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        // 3. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        request.httpBody = jsonData
        
        // 5. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 6. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 7. Decode JSON response to Post
        let decoder = JSONDecoder()
        var post = try decoder.decode(Post.self, from: data)
        
        // 8. Fix relative URLs in media files and thumbnails
        let fixedMedia = post.media.map { media -> PostMedia in
            var fixedFileUrl = media.fileUrl
            var fixedThumbnailUrl = media.thumbnailUrl
            
            // Fix file URL if it's relative
            if let fileUrl = media.fileUrl, fileUrl.hasPrefix("/") {
                fixedFileUrl = "\(baseURL)\(fileUrl)"
            }
            
            // Fix thumbnail URL if it's relative
            if let thumbnailUrl = media.thumbnailUrl, thumbnailUrl.hasPrefix("/") {
                fixedThumbnailUrl = "\(baseURL)\(thumbnailUrl)"
            }
            
            return PostMedia(
                id: media.id,
                fileUrl: fixedFileUrl,
                thumbnailUrl: fixedThumbnailUrl,
                mediaType: media.mediaType,
                order: media.order
            )
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
}

