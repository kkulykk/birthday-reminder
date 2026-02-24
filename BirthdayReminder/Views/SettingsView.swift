import SwiftUI
import SwiftData

private enum Keys {
    static let autoRefreshContacts = "autoRefreshContacts"
}

struct SettingsView: View {
    @AppStorage(Keys.autoRefreshContacts) private var autoRefreshContacts = true

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Person> { $0.isExcluded },
           sort: \Person.familyName)
    private var excludedPeople: [Person]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Contacts
                Section {
                    Toggle(isOn: $autoRefreshContacts) {
                        Label("Auto-refresh on Open", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Contacts")
                } footer: {
                    Text("Syncs birthdays from your contacts every time you open the app. New contacts are added; existing records are not duplicated.")
                }

                // MARK: Excluded Contacts
                Section {
                    if excludedPeople.isEmpty {
                        Text("No excluded contacts")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(excludedPeople) { person in
                            HStack(spacing: 12) {
                                AvatarView(person: person, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(person.fullName)
                                        .font(.body)
                                    if let month = person.birthdayMonth, let day = person.birthdayDay {
                                        Text(shortDateString(month: month, day: day))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    person.isExcluded = false
                                    try? modelContext.save()
                                } label: {
                                    Label("Include", systemImage: "eye.fill")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                } header: {
                    Text("Excluded Contacts")
                } footer: {
                    Text("Excluded contacts are hidden from your birthday list and won't receive reminders. Swipe left to restore.")
                }

                // MARK: About
                Section("About") {
                    LabeledContent("Version") {
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Build") {
                        Text(appBuild)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Helpers

    private func shortDateString(month: Int, day: Int) -> String {
        var c = DateComponents(); c.month = month; c.day = day; c.year = 2000
        guard let d = Calendar.current.date(from: c) else { return "\(month)/\(day)" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
