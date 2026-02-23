import SwiftUI
import SwiftData
import WidgetKit

@main
struct BirthdayReminderApp: App {
    let container = makeSharedModelContainer()
    @Environment(\.scenePhase) var phase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active {
                Task {
                    let ctx = ModelContext(container)
                    let people = (try? ctx.fetch(FetchDescriptor<Person>())) ?? []
                    let svc = NotificationService()
                    await svc.rescheduleAll(people: people)
                    updateWidgetData(people: people)
                }
            }
        }
    }

    private func updateWidgetData(people: [Person]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let upcoming = people
            .filter { $0.birthdayMonth != nil && $0.birthdayDay != nil && !$0.isExcluded && $0.daysUntilBirthday <= 7 }
            .sorted { $0.nextBirthdayDate < $1.nextBirthdayDate }
            .map { person in
                WidgetBirthday(
                    id: person.id,
                    name: person.fullName,
                    daysUntil: person.daysUntilBirthday,
                    isBirthdayToday: person.isBirthdayToday,
                    monthDay: formatter.string(from: person.nextBirthdayDate)
                )
            }
        WidgetDataManager.save(Array(upcoming))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
