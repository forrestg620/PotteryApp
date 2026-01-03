import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showCreatePost = false

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreatePost = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
            .task {
                await viewModel.loadPosts()
            }
        }
    }
}