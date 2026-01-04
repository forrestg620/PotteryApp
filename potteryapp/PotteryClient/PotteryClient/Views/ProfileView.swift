import SwiftUI
import Kingfisher

struct ProfileView: View {
    @ObservedObject private var networkManager = NetworkManager.shared
    @State private var posts: [Post] = []
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var selectedTab: Tab = .gallery
    @State private var isEditingIntro = false
    @State private var editingIntro: String = ""
    @State private var isUpdatingIntro = false
    @State private var showImagePicker = false
    @State private var selectedAvatarImage: UIImage? = nil
    @State private var videoURL: URL? = nil
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceSelection = false
    @State private var isUploadingAvatar = false
    
    enum Tab: String, CaseIterable, Identifiable {
        case gallery = "Gallery"
        case shop = "Shop"
        var id: String { self.rawValue }
    }
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    
    // Computed property to get profile name
    private var profileName: String {
        // First, try to get username from NetworkManager (stored during login/signup)
        if let username = networkManager.currentUsername, !username.isEmpty {
            return username
        }
        // Fallback to first post's creator username
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
                    Button(action: {
                        if !isUploadingAvatar {
                            showSourceSelection = true
                        }
                    }) {
                        ZStack {
                            if let avatarURLString = networkManager.avatarURL,
                               !avatarURLString.isEmpty,
                               let avatarURL = URL(string: avatarURLString) {
                                KFImage(avatarURL)
                                    .placeholder {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.gray)
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 72, height: 72)
                                    .foregroundColor(.gray)
                            }
                            
                            // Plus sign overlay for default avatar (hide when uploading)
                            if (networkManager.avatarURL == nil || networkManager.avatarURL?.isEmpty == true) && !isUploadingAvatar {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 24, height: 24)
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.blue)
                                        }
                                        .offset(x: 2, y: 2)
                                    }
                                }
                                .frame(width: 72, height: 72)
                            }
                            
                            // Loading indicator when uploading
                            if isUploadingAvatar {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 72, height: 72)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.top, 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isUploadingAvatar)
                    Text(profileName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Intro section - inline editing
                    VStack(spacing: 8) {
                        if isEditingIntro {
                            TextEditor(text: $editingIntro)
                                .frame(minHeight: 80, maxHeight: 120)
                                .padding(8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal, 24)
                                .padding(.top, 4)
                            
                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    editingIntro = networkManager.userIntro ?? ""
                                    isEditingIntro = false
                                }
                                .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if isUpdatingIntro {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Button("Save") {
                                        saveIntro()
                                    }
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                                }
                            }
                            .padding(.horizontal, 24)
                        } else {
                            if let intro = networkManager.userIntro, !intro.isEmpty {
                                Text(intro)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 4)
                                    .onTapGesture {
                                        editingIntro = intro
                                        isEditingIntro = true
                                    }
                            } else {
                                Button(action: {
                                    editingIntro = ""
                                    isEditingIntro = true
                                }) {
                                    Text("Tap to add intro")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }
                    
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
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    GeometryReader { geometry in
                                        ZStack {
                                            // Square image with aspect ratio - crop instead of resize
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
                                            
                                            // Play icon overlay for videos (top trailing corner)
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
                                            
                                            // Sale badge (bottom trailing)
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
            .navigationBarTitle("Profile", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        NetworkManager.shared.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .confirmationDialog("Select Photo Source", isPresented: $showSourceSelection, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") {
                        sourceType = .camera
                        showImagePicker = true
                    }
                }
                Button("Photo Library") {
                    sourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedAvatarImage, videoURL: $videoURL, sourceType: sourceType)
            }
            .onChange(of: selectedAvatarImage) { oldImage, newImage in
                if let newImage = newImage {
                    Task {
                        isUploadingAvatar = true
                        do {
                            try await networkManager.uploadAvatar(image: newImage)
                            // Clear the selected image after upload
                            selectedAvatarImage = nil
                        } catch {
                            print("Failed to upload avatar: \(error.localizedDescription)")
                        }
                        isUploadingAvatar = false
                    }
                }
            }
            .onChange(of: videoURL) { oldURL, newURL in
                // Clear video if selected (we only want images for avatar)
                if newURL != nil {
                    videoURL = nil
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .onAppear {
                fetchPosts()
                // Fetch user profile to get avatar URL
                Task {
                    do {
                        try await networkManager.fetchUserProfile()
                    } catch {
                        print("Failed to fetch profile: \(error.localizedDescription)")
                    }
                }
                // Initialize editing intro with current value
                editingIntro = networkManager.userIntro ?? ""
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
                // Fetch only the current user's posts
                let fetched = try await NetworkManager.shared.fetchMyPosts()
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
    
    private func saveIntro() {
        isUpdatingIntro = true
        Task {
            do {
                try await networkManager.updateProfile(intro: editingIntro.isEmpty ? nil : editingIntro)
                await MainActor.run {
                    isEditingIntro = false
                    isUpdatingIntro = false
                }
            } catch {
                await MainActor.run {
                    print("Failed to update intro: \(error.localizedDescription)")
                    isUpdatingIntro = false
                }
            }
        }
    }
}
