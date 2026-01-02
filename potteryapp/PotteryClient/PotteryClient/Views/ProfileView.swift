import SwiftUI
import Kingfisher

struct ProfileView: View {
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
    
    // Computed property to get profile name from posts
    private var profileName: String {
        // Get username from first post, or use default
        if let firstPost = posts.first,
           let username = firstPost.creatorUsername,
           !username.isEmpty {
            return username
        }
        return "Pottery Maker" // Default fallback
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
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
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(filteredPosts(), id: \.id) { post in
                                ZStack(alignment: .bottomTrailing) {
                                    // Square image with aspect ratio
                                    if let url = post.coverImageURL {
                                        KFImage(url)
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
                                            .aspectRatio(1, contentMode: .fill)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.1))
                                            .aspectRatio(1, contentMode: .fill)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(.gray)
                                                    .padding(12)
                                            )
                                    }
                                    
                                    if post.saleItem != nil {
                                        // Sale badge
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
                                .cornerRadius(6)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.top, 14)
                    }
                }
            }
            .navigationBarTitle("Profile", displayMode: .inline)
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
                let fetched = try await NetworkManager.shared.fetchPosts()
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
