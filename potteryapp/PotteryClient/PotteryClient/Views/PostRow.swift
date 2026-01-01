import SwiftUI
import Kingfisher
import AVKit

// Observer class for KVO
class PlayerItemObserver: NSObject {
    var onStatusChange: ((AVPlayerItem.Status) -> Void)?
    var onError: ((Error) -> Void)?
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem {
            DispatchQueue.main.async {
                self.onStatusChange?(item.status)
                if item.status == .failed, let error = item.error {
                    self.onError?(error)
                }
            }
        }
    }
}

// Separate view for video player with better error handling
struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var playerItem: AVPlayerItem?
    @State private var observer: PlayerItemObserver?
    @State private var hasError = false
    @State private var errorMessage: String?
    @State private var isReadyToPlay = false
    
    var body: some View {
        ZStack {
            if hasError {
                // Error state
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.white)
                                .font(.title)
                            Text("Video unavailable")
                                .foregroundColor(.white)
                                .font(.caption)
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            Text("URL: \(url.absoluteString)")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    )
            } else if let player = player, isReadyToPlay {
                // Video player - only show when ready
                VideoPlayer(player: player)
                    .onAppear {
                        player.isMuted = false
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                // Loading state
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Loading video...")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                        }
                    )
            }
        }
        .aspectRatio(contentMode: .fill)
        .clipped()
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    private func setupPlayer() {
        // Print URL for debugging
        print("VideoPlayerView: Setting up player with URL: \(url.absoluteString)")
        
        // Create AVURLAsset with options for better compatibility
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        
        // Load the asset's playable property to ensure it's valid
        asset.loadValuesAsynchronously(forKeys: ["playable", "tracks"]) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "playable", error: &error)
            
            DispatchQueue.main.async {
                if status == .loaded {
                    if asset.isPlayable {
                        // Asset is playable, create player item
                        self.createPlayerItem(with: asset)
                    } else {
                        print("VideoPlayerView: Asset is not playable")
                        self.hasError = true
                        self.errorMessage = "Video file is not playable. It may be corrupted or in an unsupported format."
                    }
                } else if status == .failed {
                    print("VideoPlayerView: Failed to load asset - \(error?.localizedDescription ?? "Unknown error")")
                    self.hasError = true
                    self.errorMessage = error?.localizedDescription ?? "Failed to load video asset"
                } else {
                    print("VideoPlayerView: Asset loading status: \(status.rawValue)")
                    // Try creating player anyway
                    self.createPlayerItem(with: asset)
                }
            }
        }
    }
    
    private func createPlayerItem(with asset: AVURLAsset) {
        // Create player item with the asset
        let item = AVPlayerItem(asset: asset)
        playerItem = item
        
        // Create observer
        let newObserver = PlayerItemObserver()
        newObserver.onStatusChange = { [weak newObserver] status in
            DispatchQueue.main.async {
                self.checkPlayerStatus(status: status)
            }
        }
        newObserver.onError = { error in
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = error.localizedDescription
            }
        }
        observer = newObserver
        
        // Observe player item status changes
        item.addObserver(newObserver, forKeyPath: "status", options: [.new], context: nil)
        
        // Create player
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = false
        
        // Set up loop for continuous playback
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        player = newPlayer
        
        // Check status immediately and after delays
        checkPlayerStatus(status: item.status)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let item = self.playerItem {
                self.checkPlayerStatus(status: item.status)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let item = self.playerItem {
                self.checkPlayerStatus(status: item.status)
            }
        }
    }
    
    private func checkPlayerStatus(status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            print("VideoPlayerView: Video is ready to play")
            hasError = false
            isReadyToPlay = true
        case .failed:
            if let item = playerItem {
                let errorDesc = item.error?.localizedDescription ?? "Unknown error"
                let errorCode = (item.error as NSError?)?.code ?? 0
                let errorDomain = (item.error as NSError?)?.domain ?? "Unknown"
                print("VideoPlayerView: Video failed to load")
                print("  - Error: \(errorDesc)")
                print("  - Code: \(errorCode)")
                print("  - Domain: \(errorDomain)")
                print("  - URL: \(url.absoluteString)")
                hasError = true
                errorMessage = "\(errorDesc)\n(Code: \(errorCode))"
            }
        case .unknown:
            print("VideoPlayerView: Video status is unknown, waiting...")
            // Check again after another delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let item = playerItem {
                    checkPlayerStatus(status: item.status)
                }
            }
        @unknown default:
            break
        }
    }
    
    private func cleanupPlayer() {
        player?.pause()
        if let item = playerItem, let obs = observer {
            item.removeObserver(obs, forKeyPath: "status")
            NotificationCenter.default.removeObserver(item, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        player = nil
        playerItem = nil
        observer = nil
    }
}

struct PostRow: View {
    let post: Post

    var body: some View {
        VStack(spacing: 0) {
            // Media carousel - square aspect ratio
            if !post.media.isEmpty {
                TabView {
                    ForEach(post.media) { mediaItem in
                        if let fileUrlString = mediaItem.fileUrl,
                           !fileUrlString.isEmpty,
                           let url = URL(string: fileUrlString) {
                            if mediaItem.mediaType == "image" {
                                KFImage(url)
                                    .resizable()
                                    .placeholder { 
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            } else if mediaItem.mediaType == "video" {
                                VideoPlayerView(url: url)
                            } else {
                                // Unknown media type
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "questionmark")
                                            .foregroundColor(.gray)
                                    )
                            }
                        } else {
                            // No valid URL
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    VStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.gray)
                                        Text("No media URL")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                    }
                }
                .tabViewStyle(.page)
                .aspectRatio(1, contentMode: .fit)
            } else {
                // Fallback if no media
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }

            // Details - with explicit padding to prevent edge clipping
            VStack(alignment: .leading, spacing: 8) {
                // Creator name
                if let creatorName = post.creatorUsername {
                    Text(creatorName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.leading, 16)
                }
                
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let caption = post.caption {
                            Text(caption)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .padding(.leading, 16)
                        }
                    }
                    Spacer()
                    // Price Badge
                    if post.isForSale, let saleItem = post.saleItem {
                        HStack(spacing: 6) {
                            if saleItem.isSold {
                                Text("Sold")
                                    .font(.caption).bold()
                                    .padding(6)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.gray)
                                    .cornerRadius(6)
                            }
                            Text("$\(saleItem.price)")
                                .font(.caption).bold()
                                .padding(6)
                                .background(saleItem.isSold ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
                                .foregroundColor(saleItem.isSold ? .gray : .green)
                                .cornerRadius(6)
                        }
                        .padding(.trailing, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
}
