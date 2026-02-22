import SwiftData
import Foundation

@Model
final class WishlistItem {
    var id: UUID = UUID()
    var title: String = ""
    var urlString: String?
    var notes: String?
    var createdAt: Date = Date()
    var isPurchased: Bool = false

    var person: Person?

    init() {}

    var url: URL? { urlString.flatMap { URL(string: $0) } }
}
