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
        return people.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Item preview
                Section("Saving to Wishlist") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Title", text: $itemTitle)
                            .font(.body)
                        if !itemURL.isEmpty {
                            Text(itemURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Contact picker
                Section("Choose Person") {
                    if people.isEmpty {
                        ContentUnavailableView(
                            "No Contacts",
                            systemImage: "person.slash",
                            description: Text("Open Birthday Reminder and import contacts first.")
                        )
                        .listRowBackground(Color.clear)
                    } else if filteredPeople.isEmpty {
                        Text("No results for \"\(searchText)\"")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(filteredPeople) { person in
                            let isSelected = selectedPerson?.id == person.id
                            ContactPickerRow(person: person, isSelected: isSelected)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedPerson = person }
                                .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search contacts")
            .navigationTitle("Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        extensionContext.cancelRequest(
                            withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
                        )
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(selectedPerson == nil || itemTitle.isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            loadPeople()
            parseSharedContent()
        }
    }

    // MARK: - Data loading

    private func loadPeople() {
        guard let container else { return }
        let ctx = ModelContext(container)
        let all = (try? ctx.fetch(FetchDescriptor<Person>())) ?? []
        people = all
            .filter { !$0.isExcluded && $0.birthdayMonth != nil }
            .sorted { $0.daysUntilBirthday < $1.daysUntilBirthday }
    }

    private func parseSharedContent() {
        guard let inputItems = extensionContext.inputItems as? [NSExtensionItem] else { return }
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self.itemURL = url.absoluteString
                                if self.itemTitle.isEmpty {
                                    // Use page title from the extension item if available
                                    if let title = item.attributedContentText?.string, !title.isEmpty {
                                        self.itemTitle = title
                                    } else {
                                        self.itemTitle = url.host() ?? url.absoluteString
                                    }
                                }
                            }
                        }
                    }
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                        DispatchQueue.main.async {
                            if let text = data as? String { self.itemTitle = text }
                        }
                    }
                    return
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard let person = selectedPerson, let container else { return }
        isSaving = true

        let ctx = ModelContext(container)
        let personID = person.id
        guard let saved = try? ctx.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.id == personID })
        ).first else { isSaving = false; return }

        let item = WishlistItem()
        item.title = itemTitle.trimmingCharacters(in: .whitespaces)
        item.urlString = itemURL.isEmpty ? nil : itemURL
        item.person = saved
        saved.wishlistItems.append(item)
        ctx.insert(item)
        try? ctx.save()

        extensionContext.completeRequest(returningItems: [])
    }
}

// MARK: - Contact Picker Row

private struct ContactPickerRow: View {
    let person: Person
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                if let data = person.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(person.initials.isEmpty ? "?" : person.initials)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            // Name + birthday
            VStack(alignment: .leading, spacing: 2) {
                Text(person.fullName)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let month = person.birthdayMonth, let day = person.birthdayDay {
                    Text(birthdayLabel(month: month, day: day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
        }
        .padding(.vertical, 3)
    }

    private var gradientColors: [Color] {
        let palette: [[Color]] = [
            [.blue, .indigo], [.purple, .pink],
            [.orange, .red],  [.green, .teal], [.teal, .cyan]
        ]
        return palette[abs(person.fullName.hashValue) % palette.count]
    }

    private func birthdayLabel(month: Int, day: Int) -> String {
        var c = DateComponents(); c.month = month; c.day = day; c.year = 2000
        guard let d = Calendar.current.date(from: c) else { return "\(month)/\(day)" }
        let f = DateFormatter(); f.dateFormat = "MMMM d"
        return f.string(from: d)
    }
}
