import Foundation
import SwiftData

func makeSharedModelContainer() -> ModelContainer {
    let schema = Schema([Person.self, WishlistItem.self])
    let groupID = "group.kkulykk.BirthdayReminder"

    if let groupURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
        .appending(path: "BirthdayReminder.store") {
        let config = ModelConfiguration(schema: schema, url: groupURL)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }
    }

    // Fallback: store in app's own container (works before App Group is configured)
    let config = ModelConfiguration(schema: schema)
    return try! ModelContainer(for: schema, configurations: [config])
}
