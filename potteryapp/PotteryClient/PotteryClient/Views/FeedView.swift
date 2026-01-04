import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showCreatePost = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Loading State: Show centered loading when posts are empty and loading
                    if viewModel.posts.isEmpty && viewModel.isLoading {
                        VStack {
                            Spacer()
                            ProgressView("Loading Kiln...")
                                .padding()
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    }
                    // Error State
                    else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                    // Empty State: Show when posts are empty and not loading
                    else if viewModel.posts.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "tray.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No pots found yet.")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                Task {
                                    await viewModel.loadPosts()
                                }
                            }) {
                                Text("Refresh")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    }
                    // Posts List
                    else {
                        ForEach(viewModel.posts) { post in
                            NavigationLink(destination: PostDetailView(post: post)) {
                                PostRow(post: post)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadPosts()
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