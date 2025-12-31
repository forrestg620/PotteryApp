import SwiftUI
import Kingfisher

struct PostRow: View {
    let post: Post

    var body: some View {
        VStack(spacing: 0) {
            // Image - full width
            if let imageString = post.image, let url = URL(string: imageString) {
                KFImage(url)
                    .resizable()
                    .placeholder { Rectangle().fill(Color.gray.opacity(0.2)) }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 400)
                    .clipped()
            }

            // Details - with explicit padding to prevent edge clipping
            VStack(alignment: .leading, spacing: 8) {
                // Creator name
                if let creatorName = post.creatorUsername {
                    Text(creatorName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
