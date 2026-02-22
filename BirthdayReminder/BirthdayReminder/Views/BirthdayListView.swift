import SwiftUI
import SwiftData
import Contacts

struct BirthdayListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPeople: [Person]

    @AppStorage("autoRefreshContacts") private var autoRefreshContacts = true

    @State private var showAddPerson = false
    @State private var showSettings = false
    @State private var isImportingContacts = false
    @State private var importError: String?
    @State private var showImportError = false

    @Namespace private var glassNamespace

    private let contactsService = ContactsService()
    private let notificationService = NotificationService()
    private let currentYear = Calendar.current.component(.year, from: Date())

    // MARK: - Sections

    var missedYesterdayPeople: [Person] {
        allPeople.filter { $0.isMissedYesterday }
    }

    var todayPeople: [Person] {
        allPeople.filter {
            $0.isBirthdayToday && !$0.isCongratulatedThisYear && $0.missedYear != currentYear
        }
    }

    var upcomingPeople: [Person] {
        allPeople
            .filter {
                !$0.isBirthdayToday
                && !$0.isCongratulatedThisYear
                && $0.missedYear != currentYear
                && !$0.isMissedYesterday
            }
            .sorted { $0.nextBirthdayDate < $1.nextBirthdayDate }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: []) {
                    if allPeople.isEmpty {
                        emptyState
                    } else {
                        if !missedYesterdayPeople.isEmpty {
                            birthdaySection(
                                title: "Missed — Yesterday",
                                people: missedYesterdayPeople,
                                style: .missed
                            )
                        }

                        if !todayPeople.isEmpty {
                            birthdaySection(
                                title: "Today 🎂",
                                people: todayPeople,
                                style: .today
                            )
                        }

                        if !upcomingPeople.isEmpty {
                            birthdaySection(
                                title: "Upcoming",
                                people: upcomingPeople,
                                style: .upcoming
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .navigationTitle("Birthdays")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddPerson = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task { await importContacts() }
                    } label: {
                        if isImportingContacts {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Import Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                    .disabled(isImportingContacts)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showAddPerson) {
                AddPersonView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
            .onAppear {
                autoMarkMissed()
                Task {
                    _ = await notificationService.requestPermission()
                    await notificationService.rescheduleAll(people: allPeople)
                    if autoRefreshContacts {
                        await importContacts()
                    }
                }
            }
        }
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func birthdaySection(title: String, people: [Person], style: TileStyle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: sectionIcon(for: style))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sectionColor(for: style))
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
            }
            .padding(.leading, 6)

            GlassEffectContainer {
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        NavigationLink(destination: PersonDetailView(person: person)) {
                            PersonTileView(person: person, style: style)
                        }
                        .glassEffect(in: .rect(cornerRadius: 20))
                        .glassEffectID(person.id, in: glassNamespace)

                        if index < people.count - 1 {
                            Divider().padding(.leading, 88)
                        }
                    }
                }
            }
        }
    }

    private func sectionIcon(for style: TileStyle) -> String {
        switch style {
        case .today:   return "birthday.cake.fill"
        case .missed:  return "clock.badge.exclamationmark"
        case .upcoming: return "calendar"
        }
    }

    private func sectionColor(for style: TileStyle) -> Color {
        switch style {
        case .today:   return .orange
        case .missed:  return .red
        case .upcoming: return .secondary
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.opacity(0.8))
            }

            VStack(spacing: 8) {
                Text("No Birthdays Yet")
                    .font(.title3.weight(.semibold))
                Text("Import from Contacts or tap + to add someone manually.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await importContacts() }
            } label: {
                Label("Import Contacts", systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.glass)
        }
        .padding(.vertical, 64)
        .padding(.horizontal, 32)
    }

    // MARK: - Logic

    private func autoMarkMissed() {
        let thisYear = Calendar.current.component(.year, from: Date())
        var changed = false
        for person in allPeople where person.shouldAutoMarkMissed {
            person.missedYear = thisYear
            notificationService.cancelNotification(for: person.id)
            changed = true
        }
        if changed {
            try? modelContext.save()
        }
    }

    private func importContacts() async {
        isImportingContacts = true
        defer { isImportingContacts = false }

        do {
            let granted = try await contactsService.requestPermission()
            guard granted else { return }

            let contacts = try await contactsService.fetchBirthdayContacts()
            let existingIDs = Set(allPeople.compactMap { $0.contactIdentifier })
            var newPeople: [Person] = []

            for contact in contacts {
                guard !existingIDs.contains(contact.identifier) else { continue }
                let person = Person()
                person.givenName = contact.givenName
                person.familyName = contact.familyName
                person.contactIdentifier = contact.identifier
                person.birthdayMonth = contact.birthday?.month
                person.birthdayDay = contact.birthday?.day
                person.birthdayYear = contact.birthday?.year
                person.phoneNumber = contact.phoneNumbers.first?.value.stringValue
                person.email = contact.emailAddresses.first?.value as String?
                if contact.imageDataAvailable {
                    person.photoData = contact.thumbnailImageData
                }
                modelContext.insert(person)
                newPeople.append(person)
            }

            try? modelContext.save()
            await notificationService.rescheduleAll(people: allPeople + newPeople)
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }
}
