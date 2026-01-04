//
//  PostDetailView.swift
//  PotteryClient
//
//  Created by TT on 1/3/26.
//

import SwiftUI
import Kingfisher
import AVKit
import StripePaymentSheet

struct PostDetailView: View {
    let initialPost: Post
    @State private var post: Post
    @State private var showSellSheet = false
    @State private var paymentSheet: PaymentSheet?
    @State private var showPaymentSheet = false
    @State private var showSuccessAlert = false
    @State private var isCreatingPaymentIntent = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @ObservedObject private var networkManager = NetworkManager.shared
    
    // Computed property to check if current user is the post owner
    private var isPostOwner: Bool {
        guard let currentUserId = networkManager.currentUserId else {
            return false
        }
        return post.creator == currentUserId
    }
    
    init(post: Post) {
        self.initialPost = post
        self._post = State(initialValue: post)
    }

    var body: some View {
        contentView
            .id(paymentSheet != nil ? "hasPaymentSheet" : "noPaymentSheet") // Force view update when paymentSheet changes
            .modifier(PaymentSheetModifier(
                showPaymentSheet: $showPaymentSheet,
                paymentSheet: paymentSheet,
                onCompletion: handlePaymentResult
            ))
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Media display - support both images and videos
                if !post.media.isEmpty {
                    // Use TabView for multiple media items, or single view for one item
                    if post.media.count > 1 {
                        TabView {
                            ForEach(post.media) { mediaItem in
                                mediaView(for: mediaItem)
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 400)
                        .cornerRadius(16)
                    } else if let firstMedia = post.media.first {
                        mediaView(for: firstMedia)
                            .frame(height: 400)
                            .cornerRadius(16)
                    }
                } else {
                    // Fallback if no media
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 240)
                        .cornerRadius(16)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        )
                }
                
                // User Info Row - Tappable to go to profile
                NavigationLink(destination: UserProfileView(userId: post.creator, username: post.creatorUsername)) {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.creatorUsername ?? "Unknown User")
                                .font(.headline)
                                .foregroundColor(.primary)
                            // Additional info (e.g., date) can go here
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Caption
                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                }

                Divider()

                // "Buy" Section - Show if item is for sale and not sold
                if let saleItem = post.saleItem, !saleItem.isSold {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            handleBuyButton()
                        }) {
                            HStack {
                                if isCreatingPaymentIntent {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Buy for $\(saleItem.price)")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .disabled(isCreatingPaymentIntent)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // "Sell" Section - Only show if user is the post owner
                if post.saleItem == nil && isPostOwner {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Want to sell this piece?")
                            .font(.headline)
                        
                        Button(action: {
                            showSellSheet = true
                        }) {
                            Text("List for Sale")
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                } else if post.saleItem != nil {
                    // Optionally, display sale info here
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSellSheet) {
            ListForSaleView(post: post, isPresented: $showSellSheet)
        }
        .onChange(of: showPaymentSheet) { oldValue, newValue in
            if !newValue && oldValue {
                // Payment sheet was dismissed, reset the payment sheet
                paymentSheet = nil
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pottery Purchased!")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func handleBuyButton() {
        print("PostDetailView: Buy button tapped for post \(post.id)")
        isCreatingPaymentIntent = true
        Task {
            do {
                print("PostDetailView: Creating payment intent...")
                let clientSecret = try await NetworkManager.shared.createPaymentIntent(postId: post.id)
                print("PostDetailView: Payment intent created, clientSecret: \(clientSecret.prefix(20))...")
                
                let configuration = PaymentSheet.Configuration()
                let sheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
                
                await MainActor.run {
                    print("PostDetailView: Setting payment sheet and showing...")
                    // Set paymentSheet first
                    self.paymentSheet = sheet
                    self.isCreatingPaymentIntent = false
                    
                    // Use DispatchQueue to ensure the view update happens
                    DispatchQueue.main.async {
                        print("PostDetailView: Showing payment sheet...")
                        self.showPaymentSheet = true
                        print("PostDetailView: showPaymentSheet = \(self.showPaymentSheet), paymentSheet is nil: \(self.paymentSheet == nil)")
                    }
                }
            } catch {
                print("PostDetailView: Error creating payment intent: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isCreatingPaymentIntent = false
                }
            }
        }
    }
    
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            // Mark item as sold on the backend
            Task {
                do {
                    print("PostDetailView: Marking item as sold...")
                    let updatedPost = try await NetworkManager.shared.markItemAsSold(postId: post.id)
                    await MainActor.run {
                        self.post = updatedPost
                        self.showSuccessAlert = true
                        print("PostDetailView: Item marked as sold, post updated")
                    }
                } catch {
                    print("PostDetailView: Error marking item as sold: \(error)")
                    await MainActor.run {
                        self.errorMessage = "Payment completed but failed to update item status: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        case .canceled:
            // User canceled, do nothing
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    @ViewBuilder
    private func mediaView(for mediaItem: PostMedia) -> some View {
        if mediaItem.mediaType == "image" {
            // Display image
            if let fileUrlString = mediaItem.fileUrl, !fileUrlString.isEmpty, let url = URL(string: fileUrlString) {
                KFImage(url)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                    .resizable()
                    .scaledToFit()
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        } else if mediaItem.mediaType == "video" {
            // Display video - use video file URL for playback
            if let fileUrlString = mediaItem.fileUrl, !fileUrlString.isEmpty, let url = URL(string: fileUrlString) {
                VideoPlayerView(url: url)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "video.slash")
                            .foregroundColor(.gray)
                    )
            }
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "questionmark")
                        .foregroundColor(.gray)
                )
        }
    }
}

// ViewModifier to conditionally apply payment sheet
struct PaymentSheetModifier: ViewModifier {
    @Binding var showPaymentSheet: Bool
    let paymentSheet: PaymentSheet?
    let onCompletion: (PaymentSheetResult) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if let sheet = paymentSheet {
                        Color.clear
                            .paymentSheet(isPresented: $showPaymentSheet, paymentSheet: sheet, onCompletion: onCompletion)
                    }
                }
            )
    }
}

