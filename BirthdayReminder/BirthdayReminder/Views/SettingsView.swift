import SwiftUI

private enum Keys {
    static let autoRefreshContacts = "autoRefreshContacts"
    static let notificationHour    = "notificationHour"
}

struct SettingsView: View {
    @AppStorage(Keys.autoRefreshContacts) private var autoRefreshContacts = true
    @AppStorage(Keys.notificationHour)    private var notificationHour    = 9

    @Environment(\.dismiss) private var dismiss

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

                // MARK: Notifications
                Section {
                    Picker(selection: $notificationHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formattedHour(hour)).tag(hour)
                        }
                    } label: {
                        Label("Reminder Time", systemImage: "bell.fill")
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Birthday reminders fire at this time. Changes apply the next time the app reschedules notifications.")
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedHour(_ hour: Int) -> String {
        var c = DateComponents()
        c.hour = hour
        c.minute = 0
        guard let date = Calendar.current.date(from: c) else { return "\(hour):00" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
