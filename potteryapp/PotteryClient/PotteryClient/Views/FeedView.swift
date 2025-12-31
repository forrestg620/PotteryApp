import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading {
                        ProgressView().padding()
                    } else if let error = viewModel.errorMessage {
                        Text(error).foregroundColor(.red)
                    } else {
                        ForEach(viewModel.posts) { post in
                            PostRow(post: post)
                            Divider()
                        }
                    }
                }
            }
            .navigationTitle("Pottery Feed")
            .task {
                await viewModel.loadPosts()
            }
        }
    }
}