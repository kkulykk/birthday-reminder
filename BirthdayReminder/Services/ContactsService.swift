@preconcurrency import Contacts
import Foundation

// MARK: - Protocol (for testability)

protocol ContactStoreProtocol: Sendable {
    func requestAccess(for entityType: CNEntityType, completionHandler: @escaping @Sendable (Bool, Error?) -> Void)
    func enumerateContacts(with fetchRequest: CNContactFetchRequest, usingBlock block: @escaping (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void) throws
}

extension CNContactStore: @retroactive @unchecked Sendable, ContactStoreProtocol {}

// MARK: - ContactsService

final class ContactsService {
    private let store: ContactStoreProtocol

    init(store: ContactStoreProtocol = CNContactStore()) {
        self.store = store
    }

    func requestPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Syncs birthday and photo fields from a CNContact onto an existing Person.
    /// Called during import for contacts that are already in the store.
    @MainActor
    static func applyContactFields(_ contact: CNContact, to person: Person) {
        person.birthdayMonth = contact.birthday?.month
        person.birthdayDay = contact.birthday?.day
        person.birthdayYear = contact.birthday?.year
        if contact.imageDataAvailable {
            person.photoData = contact.thumbnailImageData
        }
    }

    func fetchBirthdayContacts() async throws -> [CNContact] {
        let store = self.store
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Build request inside the closure — avoids capturing non-Sendable CNContactFetchRequest
                let keys: [String] = [
                    CNContactIdentifierKey,
                    CNContactGivenNameKey,
                    CNContactFamilyNameKey,
                    CNContactBirthdayKey,
                    CNContactPhoneNumbersKey,
                    CNContactEmailAddressesKey,
                    CNContactImageDataAvailableKey,
                    CNContactThumbnailImageDataKey
                ]
                let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
                do {
                    var contacts: [CNContact] = []
                    try store.enumerateContacts(with: request) { contact, _ in
                        if contact.birthday != nil {
                            contacts.append(contact)
                        }
                    }
                    continuation.resume(returning: contacts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
