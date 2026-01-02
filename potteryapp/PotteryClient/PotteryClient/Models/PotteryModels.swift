import Foundation

struct Post: Codable, Identifiable {
    let id: Int
    let creator: Int
    let creatorUsername: String?
    let caption: String?
    let createdAt: String     // ISO Date string
    let isForSale: Bool       // Now confirmed as Boolean!
    let saleItem: SaleItem?   // The nested sale details
    let media: [PostMedia]    // Array of media items

    enum CodingKeys: String, CodingKey {
        case id
        case creator
        case creatorUsername = "creator_username"
        case caption
        case createdAt = "created_at"
        case isForSale = "is_for_sale"
        case saleItem = "sale_item"
        case media
    }
    
    // Computed property to get the URL of the first media item (cover image)
    var coverImageURL: URL? {
        guard let firstMedia = media.first,
              let fileUrl = firstMedia.fileUrl,
              !fileUrl.isEmpty else {
            return nil
        }
        return URL(string: fileUrl)
    }
}

struct PostMedia: Codable, Identifiable {
    let id: Int
    let fileUrl: String?
    let mediaType: String
    let order: Int

    enum CodingKeys: String, CodingKey {
        case id
        case fileUrl = "file_url"
        case mediaType = "media_type"
        case order
    }
}

struct SaleItem: Codable {
    let id: Int
    let price: String // Decimal string (e.g. "25.00")
    let isSold: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case price
        case isSold = "is_sold"
    }
}