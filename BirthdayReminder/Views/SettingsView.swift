import SwiftUI
import SwiftData

private enum Keys {
    static let autoRefreshContacts = "autoRefreshContacts"
    static let anthropicAPIKey = "anthropicAPIKey"
    static let anthropicCustomPrompt = "anthropicCustomPrompt"
    static let openAIAPIKey = "openAIAPIKey"
    static let aiProvider = "aiProvider"
    static let aiEnabled = "aiEnabled"
}

private enum KeyStatus: Equatable {
    case idle
    case validating
    case valid
    case invalid(String)
}

// MARK: - SettingsViewLogic (testable pure helpers)

enum SettingsViewLogic {
    /// Formats a month/day pair as a short date string (e.g. "Mar 8").
    static func shortDateString(month: Int, day: Int) -> String {
        var c = DateComponents(); c.month = month; c.day = day; c.year = 2000
        guard let d = Calendar.current.date(from: c) else { return "\(month)/\(day)" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    /// Returns a short, user-readable description of an API key validation error.
    static func shortValidationError(_ error: Error) -> String {
        if let e = error as? AnthropicError {
            switch e {
            case .invalidAPIKey: return "Invalid API key"
            case .networkError: return "Network error — check your connection"
            case .apiError(let msg): return msg
            case .parsingError: return "Unexpected response"
            }
        }
        if let e = error as? OpenAIError {
            switch e {
            case .invalidAPIKey: return "Invalid API key"
            case .networkError: return "Network error — check your connection"
            case .apiError(let msg): return msg
            case .parsingError: return "Unexpected response"
            }
        }
        return error.localizedDescription
    }
}

// MARK: - SettingsView

private enum APIKeyField: Hashable { case anthropic, openai }

struct SettingsView: View {
    @AppStorage(Keys.autoRefreshContacts) private var autoRefreshContacts = true
    @AppStorage(Keys.anthropicAPIKey) private var anthropicAPIKey = ""
    @AppStorage(Keys.anthropicCustomPrompt) private var anthropicCustomPrompt = ""
    @AppStorage(Keys.openAIAPIKey) private var openAIAPIKey = ""
    @AppStorage(Keys.aiProvider) private var aiProvider = "anthropic"
    @AppStorage(Keys.aiEnabled) private var aiEnabled = false

    @State private var anthropicKeyStatus: KeyStatus = .idle
    @State private var openAIKeyStatus: KeyStatus = .idle
    @FocusState private var focusedField: APIKeyField?

    private var currentKeyStatus: KeyStatus {
        aiProvider == "openai" ? openAIKeyStatus : anthropicKeyStatus
    }

    private var currentKey: String {
        aiProvider == "openai" ? openAIAPIKey : anthropicAPIKey
    }

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
                                        Text(SettingsViewLogic.shortDateString(month: month, day: day))
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

                // MARK: AI Congratulations
                Section {
                    Toggle(isOn: $aiEnabled) {
                        Label("Enable AI Congratulations", systemImage: "sparkles")
                    }

                    if aiEnabled {
                        Picker("Provider", selection: $aiProvider) {
                            Text("Anthropic").tag("anthropic")
                            Text("OpenAI").tag("openai")
                        }

                        if aiProvider == "anthropic" {
                            SecureField("Paste your Anthropic API key...", text: $anthropicAPIKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .anthropic)
                                .onSubmit { validateCurrentKey() }
                                .onChange(of: anthropicAPIKey) { anthropicKeyStatus = .idle }
                        } else {
                            SecureField("Paste your OpenAI API key...", text: $openAIAPIKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .openai)
                                .onSubmit { validateCurrentKey() }
                                .onChange(of: openAIAPIKey) { openAIKeyStatus = .idle }
                        }

                        keyStatusRow

                        TextField("Custom prompt (optional)", text: $anthropicCustomPrompt, axis: .vertical)
                            .lineLimit(3)
                    }
                } header: {
                    Text("AI Congratulations")
                } footer: {
                    Text("Your key is stored locally on device only. Get yours at anthropic.com or platform.openai.com.")
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
                // Keyboard toolbar — "Done" dismisses the API key field
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    // MARK: - Key Status UI

    @ViewBuilder
    private var keyStatusRow: some View {
        if !currentKey.isEmpty || currentKeyStatus != .idle {
            HStack(spacing: 8) {
                switch currentKeyStatus {
                case .idle:
                    Image(systemName: "key.slash")
                        .foregroundStyle(.secondary)
                    Text("Not validated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .validating:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Validating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .valid:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Key is valid")
                        .font(.caption)
                        .foregroundStyle(.green)
                case .invalid(let msg):
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                if currentKeyStatus != .validating {
                    Button("Validate") { validateCurrentKey() }
                        .font(.caption)
                        .disabled(currentKey.isEmpty)
                }
            }
        }
    }

    // MARK: - Validation

    private func validateCurrentKey() {
        guard !currentKey.isEmpty else { return }
        let provider = aiProvider
        let key = currentKey
        setKeyStatus(.validating, for: provider)
        Task {
            do {
                if provider == "openai" {
                    try await OpenAIService().validateAPIKey(key)
                } else {
                    try await AnthropicService().validateAPIKey(key)
                }
                if aiProvider == provider { setKeyStatus(.valid, for: provider) }
            } catch {
                if aiProvider == provider {
                    setKeyStatus(.invalid(SettingsViewLogic.shortValidationError(error)), for: provider)
                }
            }
        }
    }

    private func setKeyStatus(_ status: KeyStatus, for provider: String) {
        if provider == "openai" {
            openAIKeyStatus = status
        } else {
            anthropicKeyStatus = status
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
