//
//  PostDetailView.swift
//  PotteryClient
//
//  Created by TT on 1/3/26.
//

import SwiftUI
import Kingfisher
import AVKit

struct PostDetailView: View {
    let post: Post
    @State private var showSellSheet = false

    var body: some View {
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
                
                // User Info Row
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
                }
                
                // Caption
                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                }

                Divider()

                // "Sell" Section
                if post.saleItem == nil {
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

