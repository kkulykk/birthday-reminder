import SwiftUI
import SwiftData

struct WishlistView: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var modelContext
    @State private var showAddItem = false

    var sortedItems: [WishlistItem] {
        person.wishlistItems.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            if sortedItems.isEmpty {
                ContentUnavailableView(
                    "No Wishlist Items",
                    systemImage: "gift",
                    description: Text("Add items from any app using the Share Sheet, or tap + to add manually.")
                )
            } else {
                ForEach(sortedItems) { item in
                    WishlistItemRow(item: item)
                }
                .onDelete { indexSet in
                    deleteItems(at: indexSet, from: sortedItems)
                }
            }
        }
        .navigationTitle("Wishlist")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddWishlistItemView(person: person)
        }
    }

    private func deleteItems(at indexSet: IndexSet, from items: [WishlistItem]) {
        for index in indexSet {
            modelContext.delete(items[index])
        }
        try? modelContext.save()
    }
}

struct WishlistItemRow: View {
    @Bindable var item: WishlistItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isPurchased.toggle()
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isPurchased)
                    .foregroundStyle(item.isPurchased ? .secondary : .primary)

                if let urlString = item.urlString, !urlString.isEmpty {
                    Text(urlString)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
