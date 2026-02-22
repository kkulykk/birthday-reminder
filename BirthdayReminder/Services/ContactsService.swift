@preconcurrency import Contacts
import Foundation

@MainActor
final class ContactsService {

    func requestPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchBirthdayContacts() async throws -> [CNContact] {
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
                    let store = CNContactStore()
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
