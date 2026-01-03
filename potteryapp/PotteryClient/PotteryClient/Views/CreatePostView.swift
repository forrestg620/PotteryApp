import SwiftUI
import AVKit
import AVFoundation


struct CreatePostView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var caption: String = ""
    @State private var selectedImage: UIImage?
    @State private var videoURL: URL? = nil
    @State private var videoThumbnail: UIImage? = nil
    @State private var showPicker: Bool = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceSelection: Bool = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isUploading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // Caption Area
                ZStack(alignment: .topLeading) {
                    if caption.isEmpty {
                        Text("Write a caption...")
                            .foregroundColor(Color.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $caption)
                        .padding(6)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)

                // Image Area
                Button(action: {
                    showSourceSelection = true
                }) {
                    if let videoThumbnail = videoThumbnail {
                        ZStack {
                            Image(uiImage: videoThumbnail)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260, maxHeight: 260)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            
                            // Play icon overlay
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                        }
                    } else if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260, maxHeight: 260)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Add Photo")
                                .foregroundColor(.gray)
                                .font(.headline)
                        }
                        .frame(width: 180, height: 180)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(16)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .confirmationDialog("Select Photo Source", isPresented: $showSourceSelection, titleVisibility: .visible) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Camera") {
                            sourceType = .camera
                            showPicker = true
                        }
                    }
                    Button("Photo Library") {
                        sourceType = .photoLibrary
                        showPicker = true
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .sheet(isPresented: $showPicker) {
                    ImagePicker(selectedImage: $selectedImage, videoURL: $videoURL, sourceType: sourceType)
                }
                .onChange(of: videoURL) { oldValue, newValue in
                    if let newValue = newValue {
                        generateVideoThumbnail(from: newValue)
                    } else {
                        videoThumbnail = nil
                    }
                }
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        handlePost()
                    }
                    .disabled((selectedImage == nil && videoURL == nil) || isUploading)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func handlePost() {
        guard selectedImage != nil || videoURL != nil else {
            errorMessage = "Please select an image or video"
            showingError = true
            return
        }
        
        isUploading = true
        Task {
            do {
                if let image = selectedImage {
                    // Upload image
                    try await NetworkManager.shared.uploadPost(image: image, caption: caption)
                } else if let videoURL = videoURL {
                    // Upload video
                    try await NetworkManager.shared.uploadPostWithVideo(videoURL: videoURL, caption: caption)
                }
                
                await MainActor.run {
                    isUploading = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isUploading = false
                }
            }
        }
    }
    
    private func generateVideoThumbnail(from url: URL) {
        Task {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            do {
                let cgImage = try await imageGenerator.image(at: CMTime.zero).image
                await MainActor.run {
                    videoThumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                print("Failed to generate video thumbnail: \(error)")
            }
        }
    }
}

#Preview {
    CreatePostView()
}
