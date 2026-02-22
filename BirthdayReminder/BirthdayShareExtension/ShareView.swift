import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareView: View {
    let extensionContext: NSExtensionContext

    @State private var people: [Person] = []
    @State private var selectedPerson: Person?
    @State private var itemTitle = ""
    @State private var itemURL = ""
    @State private var isSaving = false
    @State private var searchText = ""

    private let container: ModelContainer? = {
        let schema = Schema([Person.self, WishlistItem.self])
        let groupID = "group.kkulykk.BirthdayReminder"
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appending(path: "BirthdayReminder.store") else { return nil }
        let config = ModelConfiguration(schema: schema, url: groupURL)
        return try? ModelContainer(for: schema, configurations: [config])
    }()

    var filteredPeople: [Person] {
        if searchText.isEmpty { return people }
        return people.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Item details section
                Form {
                    Section("Wishlist Item") {
                        TextField("Title", text: $itemTitle)
                        if !itemURL.isEmpty {
                            Text(itemURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Section("Add to Person's Wishlist") {
                        if people.isEmpty {
                            Text("No people found. Open Birthday Reminder to add contacts.")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        } else {
                            ForEach(filteredPeople) { person in
                                HStack {
                                    Text(person.fullName)
                                    Spacer()
                                    if selectedPerson?.id == person.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPerson = person
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search people")
            }
            .navigationTitle("Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        extensionContext.cancelRequest(
                            withError: NSError(
                                domain: NSCocoaErrorDomain,
                                code: NSUserCancelledError
                            )
                        )
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        save()
                    }
                    .disabled(selectedPerson == nil || itemTitle.isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            loadPeople()
            parseSharedContent()
        }
    }

    private func loadPeople() {
        guard let container else { return }
        let ctx = ModelContext(container)
        people = (try? ctx.fetch(FetchDescriptor<Person>())) ?? []
        people.sort { $0.fullName < $1.fullName }
    }

    private func parseSharedContent() {
        guard let inputItems = extensionContext.inputItems as? [NSExtensionItem] else { return }
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                // Try URL first
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self.itemURL = url.absoluteString
                                if self.itemTitle.isEmpty {
                                    self.itemTitle = url.host() ?? url.absoluteString
                                }
                            }
                        }
                    }
                    return
                }
                // Try plain text
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                        DispatchQueue.main.async {
                            if let text = data as? String {
                                self.itemTitle = text
                            }
                        }
                    }
                    return
                }
            }
        }
    }

    private func save() {
        guard let person = selectedPerson, let container else { return }
        isSaving = true

        let ctx = ModelContext(container)
        // Re-fetch the person in this context to ensure correct binding
        let personID = person.id
        guard let savedPerson = try? ctx.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.id == personID })
        ).first else {
            isSaving = false
            return
        }

        let item = WishlistItem()
        item.title = itemTitle.trimmingCharacters(in: .whitespaces)
        item.urlString = itemURL.isEmpty ? nil : itemURL
        item.person = savedPerson
        savedPerson.wishlistItems.append(item)
        ctx.insert(item)
        try? ctx.save()

        extensionContext.completeRequest(returningItems: [])
    }
}
