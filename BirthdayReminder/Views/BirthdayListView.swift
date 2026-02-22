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
    @State private var upcomingShowCount = 5

    private let contactsService = ContactsService()
    private let notificationService = NotificationService()
    private let currentYear = Calendar.current.component(.year, from: Date())

    // MARK: - Filtered base

    var activePeople: [Person] {
        allPeople.filter { !$0.isExcluded }
    }

    // MARK: - Sections

    var missedYesterdayPeople: [Person] {
        activePeople.filter { $0.isMissedYesterday }
    }

    var todayPeople: [Person] {
        activePeople.filter {
            $0.isBirthdayToday && !$0.isCongratulatedThisYear && $0.missedYear != currentYear
        }
    }

    var upcomingPeople: [Person] {
        activePeople
            .filter {
                !$0.isBirthdayToday
                && !$0.isCongratulatedThisYear
                && $0.missedYear != currentYear
                && !$0.isMissedYesterday
            }
            .sorted { $0.nextBirthdayDate < $1.nextBirthdayDate }
    }

    var visibleUpcomingPeople: [Person] {
        Array(upcomingPeople.prefix(upcomingShowCount))
    }

    var pastPeople: [Person] {
        activePeople
            .filter { person in
                let lastBdYear = Calendar.current.component(.year, from: person.lastBirthdayDate)
                let processed = person.congratulatedYear == lastBdYear || person.missedYear == lastBdYear
                // Include if processed this calendar year, OR within 45 days (catches Dec birthdays in Jan)
                let isThisCalYear = lastBdYear == currentYear
                let isRecent = person.daysSinceLastBirthday <= 45
                return processed && (isThisCalYear || isRecent)
            }
            .sorted { $0.daysSinceLastBirthday < $1.daysSinceLastBirthday }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if allPeople.isEmpty {
                    emptyState
                } else {
                    List {
                        // Missed section
                        if !missedYesterdayPeople.isEmpty {
                            Section {
                                ForEach(missedYesterdayPeople) { person in
                                    NavigationLink(destination: PersonDetailView(person: person, style: .missed)) {
                                        PersonTileView(person: person, style: .missed)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        excludeButton(person)
                                    }
                                }
                            } header: {
                                Label("Missed — Yesterday", systemImage: "clock.badge.exclamationmark")
                                    .foregroundStyle(.red)
                            }
                        }

                        // Today section — swipe right to congratulate
                        if !todayPeople.isEmpty {
                            Section {
                                ForEach(todayPeople) { person in
                                    NavigationLink(destination: PersonDetailView(person: person, style: .today)) {
                                        PersonTileView(person: person, style: .today)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            markCongratulated(person)
                                        } label: {
                                            Label("Congrats!", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        excludeButton(person)
                                    }
                                }
                            } header: {
                                Label("Today 🎂", systemImage: "birthday.cake.fill")
                                    .foregroundStyle(.orange)
                            }
                        }

                        // Upcoming section — 5 at a time
                        if !upcomingPeople.isEmpty {
                            Section {
                                ForEach(visibleUpcomingPeople) { person in
                                    NavigationLink(destination: PersonDetailView(person: person, style: .upcoming)) {
                                        PersonTileView(person: person, style: .upcoming)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        excludeButton(person)
                                    }
                                }
                                if upcomingPeople.count > upcomingShowCount {
                                    Button {
                                        upcomingShowCount += 5
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Text("Show More")
                                                .font(.subheadline.weight(.medium))
                                            Spacer()
                                        }
                                    }
                                }
                            } header: {
                                Label("Upcoming", systemImage: "calendar")
                            }
                        }

                        // Past birthdays
                        if !pastPeople.isEmpty {
                            Section {
                                ForEach(pastPeople) { person in
                                    NavigationLink(destination: PersonDetailView(person: person, style: .past)) {
                                        PersonTileView(person: person, style: .past)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        if person.isCongratulatedOnLastBirthday {
                                            Button {
                                                restorePerson(person)
                                            } label: {
                                                Label("Undo", systemImage: "arrow.uturn.left.circle.fill")
                                            }
                                            .tint(.blue)
                                        } else {
                                            Button {
                                                markCongratulatedPast(person)
                                            } label: {
                                                Label("Congrats!", systemImage: "checkmark.circle.fill")
                                            }
                                            .tint(.green)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        excludeButton(person)
                                    }
                                }
                            } header: {
                                Label("Past — This Year", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
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
                    await notificationService.rescheduleAll(people: activePeople)
                    if autoRefreshContacts {
                        await importContacts()
                    }
                }
            }
        }
    }

    // MARK: - Swipe Action Builder

    @ViewBuilder
    private func excludeButton(_ person: Person) -> some View {
        Button(role: .destructive) {
            excludePerson(person)
        } label: {
            Label("Exclude", systemImage: "eye.slash.fill")
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

    private func markCongratulated(_ person: Person) {
        let thisYear = Calendar.current.component(.year, from: Date())
        person.congratulatedYear = thisYear
        notificationService.cancelNotification(for: person.id)
        try? modelContext.save()
        Task {
            await notificationService.rescheduleAll(people: activePeople)
        }
    }

    private func markCongratulatedPast(_ person: Person) {
        let lastBdYear = Calendar.current.component(.year, from: person.lastBirthdayDate)
        person.congratulatedYear = lastBdYear
        try? modelContext.save()
    }

    private func restorePerson(_ person: Person) {
        person.congratulatedYear = nil
        person.missedYear = nil
        try? modelContext.save()
        Task {
            await notificationService.rescheduleAll(people: activePeople)
        }
    }

    private func excludePerson(_ person: Person) {
        person.isExcluded = true
        notificationService.cancelNotification(for: person.id)
        try? modelContext.save()
    }

    private func autoMarkMissed() {
        let thisYear = Calendar.current.component(.year, from: Date())
        var changed = false
        for person in activePeople where person.shouldAutoMarkMissed {
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

            let existingByID = Dictionary(uniqueKeysWithValues:
                allPeople.compactMap { p in p.contactIdentifier.map { ($0, p) } }
            )

            var newPeople: [Person] = []

            for contact in contacts {
                if let existing = existingByID[contact.identifier] {
                    if contact.imageDataAvailable {
                        existing.photoData = contact.thumbnailImageData
                    }
                } else {
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
            }

            try? modelContext.save()
            await notificationService.rescheduleAll(people: activePeople + newPeople)
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }
}
