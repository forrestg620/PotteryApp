import Foundation
import Observation

@Observable
class FeedViewModel {
    var posts: [Post] = []
    var isLoading = false
    var errorMessage: String?

    func loadPosts() async {
        isLoading = true
        errorMessage = nil

        do {
            self.posts = try await NetworkManager.shared.fetchPosts()
        } catch {
            self.errorMessage = "Failed to load: \(error.localizedDescription)"
            print("Error: \(error)")
        }

        isLoading = false
    }
}