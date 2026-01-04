import SwiftUI
import Kingfisher

struct UserProfileView: View {
    let userId: Int
    let username: String?
    
    @State private var posts: [Post] = []
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var selectedTab: Tab = .gallery
    
    enum Tab: String, CaseIterable, Identifiable {
        case gallery = "Gallery"
        case shop = "Shop"
        var id: String { self.rawValue }
    }
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    
    // Computed property to get profile name
    private var profileName: String {
        if let username = username, !username.isEmpty {
            return username
        }
        if let firstPost = posts.first,
           let username = firstPost.creatorUsername,
           !username.isEmpty {
            return username
        }
        return "Pottery Maker"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    // Avatar (read-only, no upload)
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundColor(.gray)
                        .padding(.top, 24)
                    
                    Text(profileName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer(minLength: 8)
                }
                
                // Segmented Picker
                Picker("View", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Grid
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else if showError {
                        Text("Failed to load posts.")
                            .foregroundColor(.red)
                            .padding(.top, 60)
                    } else if posts.isEmpty {
                        // Empty State
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "camera.metering.center.weighted")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No pottery yet.")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Upload your first work!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(filteredPosts(), id: \.id) { post in
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    GeometryReader { geometry in
                                        ZStack {
                                            KFImage(post.coverImageURL)
                                                .placeholder {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .resizable()
                                                                .scaledToFit()
                                                                .foregroundColor(.gray)
                                                                .padding(12)
                                                        )
                                                }
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: geometry.size.width, height: geometry.size.width)
                                                .clipped()
                                            
                                            if post.media.first?.mediaType == "video" {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        Image(systemName: "play.fill")
                                                            .font(.caption)
                                                            .foregroundColor(.white)
                                                            .padding(6)
                                                            .background(Color.black.opacity(0.6))
                                                            .clipShape(Circle())
                                                            .padding(6)
                                                    }
                                                    Spacer()
                                                }
                                            }
                                            
                                            if post.saleItem != nil {
                                                VStack {
                                                    Spacer()
                                                    HStack {
                                                        Spacer()
                                                        ZStack {
                                                            Circle()
                                                                .fill(Color.green)
                                                                .frame(width: 24, height: 24)
                                                            Text("$")
                                                                .font(.caption).bold()
                                                                .foregroundColor(.white)
                                                        }
                                                        .padding(6)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .cornerRadius(6)
                                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.top, 14)
                    }
                }
            }
            .navigationBarTitle(profileName, displayMode: .inline)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .onAppear {
                fetchPosts()
            }
        }
    }
    
    private func filteredPosts() -> [Post] {
        switch selectedTab {
        case .gallery:
            return posts
        case .shop:
            return posts.filter { $0.saleItem != nil }
        }
    }
    
    private func fetchPosts() {
        isLoading = true
        showError = false
        Task {
            do {
                let fetched = try await NetworkManager.shared.fetchPostsByUserId(userId: userId)
                DispatchQueue.main.async {
                    self.posts = fetched
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
}

