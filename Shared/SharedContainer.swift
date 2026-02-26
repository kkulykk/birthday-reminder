import Foundation
import SwiftData

func makeSharedModelContainer(
    groupURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.kkulykk.BirthdayReminder")?
        .appending(path: "BirthdayReminder.store")
) -> ModelContainer {
    let schema = Schema([Person.self, WishlistItem.self])

    if let groupURL {
        let config = ModelConfiguration(schema: schema, url: groupURL)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }
    }

    // Fallback: store in app's own container (works before App Group is configured)
    let config = ModelConfiguration(schema: schema)
    return try! ModelContainer(for: schema, configurations: [config])
}
