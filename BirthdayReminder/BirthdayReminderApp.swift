import SwiftUI
import SwiftData

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
                }
            }
        }
    }
}
