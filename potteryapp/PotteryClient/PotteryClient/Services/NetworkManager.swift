import Foundation
import UIKit
import Combine

class NetworkManager: ObservableObject {
    // Singleton - One shared instance for the whole app
    static let shared = NetworkManager()
    
    // Base URL for the Django backend
    //   private let baseURL = "https://episcopally-jennifer-preaccessible.ngrok-free.dev"
    private let baseURL = "https://unpaid-luciana-unchronically.ngrok-free.dev"
//    private let baseURL = "http://127.0.0.1:8000"
    
    // UserDefaults keys
    private let authTokenKey = "authToken"
    private let usernameKey = "username"
    private let avatarURLKey = "avatarURL"
    
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
    
    // Published property for current username
    @Published var currentUsername: String? {
        didSet {
            if let username = currentUsername {
                UserDefaults.standard.set(username, forKey: usernameKey)
            } else {
                UserDefaults.standard.removeObject(forKey: usernameKey)
            }
        }
    }
    
    // Published property for avatar URL
    @Published var avatarURL: String? {
        didSet {
            if let url = avatarURL {
                UserDefaults.standard.set(url, forKey: avatarURLKey)
            } else {
                UserDefaults.standard.removeObject(forKey: avatarURLKey)
            }
        }
    }
    
    // Published property for user intro
    @Published var userIntro: String? {
        didSet {
            if let intro = userIntro {
                UserDefaults.standard.set(intro, forKey: "userIntro")
            } else {
                UserDefaults.standard.removeObject(forKey: "userIntro")
            }
        }
    }
    
    // Published property for current user ID
    @Published var currentUserId: Int? {
        didSet {
            if let userId = currentUserId {
                UserDefaults.standard.set(userId, forKey: "currentUserId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentUserId")
            }
        }
    }
    
    private init() {
        // Check if auth token exists on initialization
        if authToken != nil {
            isAuthenticated = true
            // Load username, avatar URL, intro, and user ID from UserDefaults
            currentUsername = UserDefaults.standard.string(forKey: usernameKey)
            avatarURL = UserDefaults.standard.string(forKey: avatarURLKey)
            userIntro = UserDefaults.standard.string(forKey: "userIntro")
            currentUserId = UserDefaults.standard.object(forKey: "currentUserId") as? Int
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
        self.currentUsername = username // Store the username
        self.isAuthenticated = true
        
        // 8. Fetch user profile to get avatar URL
        Task {
            do {
                try await self.fetchUserProfile()
            } catch {
                // Silently fail - avatar will just be nil
                print("Failed to fetch profile after login: \(error.localizedDescription)")
            }
        }
    }
    
    func signUp(username: String, password: String, avatar: UIImage?) async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/register/") else {
            throw URLError(.badURL)
        }
        
        // 2. Generate unique boundary
        let boundary = UUID().uuidString
        
        // 3. Create multipart/form-data body
        var body = Data()
        
        // Append username field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"username\"\r\n\r\n".data(using: .utf8)!)
        body.append(username.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Append password field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"password\"\r\n\r\n".data(using: .utf8)!)
        body.append(password.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Append avatar field if provided
        if let avatar = avatar {
            // Compress avatar to JPEG with 0.5 quality
            guard let avatarData = avatar.jpegData(compressionQuality: 0.5) else {
                throw URLError(.cannotDecodeContentData)
            }
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(avatarData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 4. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.httpBody = body
        
        // 5. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 6. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Sign up error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Sign up failed: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 7. Decode JSON response to extract token, username, and avatar
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw NSError(domain: "NetworkError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode token from response"
            ])
        }
        
        // 8. Save token, username, user_id, avatar, and update authentication status
        self.authToken = token
        if let username = json["username"] as? String {
            self.currentUsername = username
        }
        if let userId = json["user_id"] as? Int {
            self.currentUserId = userId
        }
        if let avatarURL = json["avatar_url"] as? String, !avatarURL.isEmpty {
            // Fix relative URL if needed
            let fixedURL = avatarURL.hasPrefix("/") ? "\(baseURL)\(avatarURL)" : avatarURL
            self.avatarURL = fixedURL
            print("NetworkManager: Stored avatar URL from signup: \(fixedURL)")
        } else {
            print("NetworkManager: No avatar_url in signup response, will fetch profile")
        }
        self.isAuthenticated = true
        
        // 9. Fetch user profile to ensure we have the latest avatar URL
        Task {
            do {
                try await self.fetchUserProfile()
            } catch {
                print("NetworkManager: Failed to fetch profile after signup: \(error.localizedDescription)")
            }
        }
    }
    
    func signOut() {
        // Clear token, username, user_id, avatar, and intro (this also removes them from UserDefaults via the setters)
        authToken = nil
        currentUsername = nil
        currentUserId = nil
        avatarURL = nil
        userIntro = nil
        isAuthenticated = false
    }
    
    // MARK: - Profile
    
    func fetchUserProfile() async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/profile/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        
        // 3. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 4. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Profile fetch error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Profile fetch failed: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 5. Decode JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "NetworkError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode profile response"
            ])
        }
        
        // 6. Update username, user_id, avatar URL, and intro
        if let username = json["username"] as? String {
            self.currentUsername = username
        }
        if let userId = json["user_id"] as? Int {
            self.currentUserId = userId
        }
        if let avatarURL = json["avatar_url"] as? String, !avatarURL.isEmpty {
            // Fix relative URL if needed
            let fixedURL = avatarURL.hasPrefix("/") ? "\(baseURL)\(avatarURL)" : avatarURL
            self.avatarURL = fixedURL
            print("NetworkManager: Fetched and stored avatar URL: \(fixedURL)")
        } else {
            self.avatarURL = nil
            print("NetworkManager: No avatar_url in profile response or it's empty")
        }
        if let intro = json["intro"] as? String {
            self.userIntro = intro
        } else {
            self.userIntro = nil
        }
    }
    
    func updateProfile(intro: String?) async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/profile/") else {
            throw URLError(.badURL)
        }
        
        // 2. Create JSON body
        var body: [String: Any?] = [:]
        if let intro = intro {
            body["intro"] = intro
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 }) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        // 3. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        request.httpBody = jsonData
        
        // 4. Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 5. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Profile update error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Profile update failed: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 6. Decode JSON response and update local state
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "NetworkError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode profile update response"
            ])
        }
        
        // 7. Update local state
        if let intro = json["intro"] as? String {
            self.userIntro = intro
        }
    }
    
    func uploadAvatar(image: UIImage) async throws {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/api/profile/") else {
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
        
        // Append avatar field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 5. Create request
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
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
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Avatar upload error response: \(errorString)")
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Avatar upload failed: \(httpResponse.statusCode)",
                        "response": errorString
                    ])
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // 8. Decode JSON response and update local state
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "NetworkError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode avatar upload response"
            ])
        }
        
        // 9. Update avatar URL
        if let avatarURL = json["avatar_url"] as? String, !avatarURL.isEmpty {
            // Fix relative URL if needed
            let fixedURL = avatarURL.hasPrefix("/") ? "\(baseURL)\(avatarURL)" : avatarURL
            self.avatarURL = fixedURL
            print("NetworkManager: Updated avatar URL: \(fixedURL)")
        }
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
    
    func fetchPostsByUserId(userId: Int) async throws -> [Post] {
        // 1. Construct the URL with user_id query parameter
        guard let url = URL(string: "\(baseURL)/api/posts/user_posts/?user_id=\(userId)") else {
            throw URLError(.badURL)
        }
        
        // 2. Create request
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        addAuthHeader(to: &request)
        
        // 3. Fetch Data (Network Call)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 4. Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
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

