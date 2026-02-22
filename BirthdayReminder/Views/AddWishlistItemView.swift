import SwiftUI
import SwiftData

struct AddWishlistItemView: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var urlString = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $title)
                    TextField("URL (optional)", text: $urlString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let item = WishlistItem()
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.urlString = urlString.trimmingCharacters(in: .whitespaces).isEmpty ? nil : urlString.trimmingCharacters(in: .whitespaces)
        item.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        item.person = person
        person.wishlistItems.append(item)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
