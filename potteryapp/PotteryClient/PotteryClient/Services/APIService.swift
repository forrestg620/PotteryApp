import Foundation

class APIService {
    // Singleton - One shared instance for the whole app
    static let shared = APIService()
    
    // 127.0.0.1 is the address of "Localhost" inside the Simulator
    private let baseURL = "http://127.0.0.1:8000/api"

    func fetchPosts() async throws -> [Post] {
        // 1. Construct the URL
        guard let url = URL(string: "\(baseURL)/posts/") else {
            throw URLError(.badURL)
        }
        
        // 2. Fetch Data (Network Call)
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // 3. Decode JSON into Swift Objects
        let decoder = JSONDecoder()
        // We don't use .convertFromSnakeCase here because we manually defined keys in CodingKeys
        // but adding it doesn't hurt if keys match.
        
        return try decoder.decode([Post].self, from: data)
    }
}