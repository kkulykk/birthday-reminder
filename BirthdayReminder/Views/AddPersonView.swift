import SwiftUI
import SwiftData

struct AddPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var givenName = ""
    @State private var familyName = ""
    @State private var hasBirthday = true
    @State private var birthday = Date()
    @State private var hasYear = false
    @State private var phoneNumber = ""
    @State private var email = ""

    private let notificationService = NotificationService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $givenName)
                    TextField("Last Name", text: $familyName)
                }

                Section("Birthday") {
                    Toggle("Has Birthday", isOn: $hasBirthday)
                    if hasBirthday {
                        Toggle("Include Year", isOn: $hasYear)
                        DatePicker(
                            "Birthday",
                            selection: $birthday,
                            displayedComponents: hasYear ? [.date] : [.date]
                        )
                        .datePickerStyle(.graphical)
                    }
                }

                Section("Contact") {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(givenName.trimmingCharacters(in: .whitespaces).isEmpty &&
                                  familyName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let person = Person()
        person.givenName = givenName.trimmingCharacters(in: .whitespaces)
        person.familyName = familyName.trimmingCharacters(in: .whitespaces)
        person.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phoneNumber
        person.email = email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email

        if hasBirthday {
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month, .day], from: birthday)
            person.birthdayMonth = comps.month
            person.birthdayDay = comps.day
            person.birthdayYear = hasYear ? comps.year : nil
        }

        modelContext.insert(person)
        try? modelContext.save()
        dismiss()
    }
}
