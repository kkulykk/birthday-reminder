import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct BirthdayEntry: TimelineEntry {
    let date: Date
    let upcomingBirthdays: [WidgetBirthday]

    /// Only the birthdays on the nearest upcoming day.
    /// If two people share the same day, both are included.
    var nearestDay: [WidgetBirthday] {
        guard let first = upcomingBirthdays.first else { return [] }
        return upcomingBirthdays.filter { $0.daysUntil == first.daysUntil }
    }
}

// MARK: - Timeline Provider

struct BirthdayProvider: TimelineProvider {
    func placeholder(in context: Context) -> BirthdayEntry {
        BirthdayEntry(date: Date(), upcomingBirthdays: [
            WidgetBirthday(id: UUID(), name: "Alex Smith", daysUntil: 3, isBirthdayToday: false, monthDay: "Feb 26"),
            WidgetBirthday(id: UUID(), name: "Maria Garcia", daysUntil: 3, isBirthdayToday: false, monthDay: "Feb 26"),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        let entry = BirthdayEntry(date: Date(), upcomingBirthdays: WidgetDataManager.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        let stored = WidgetDataManager.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Generate one entry per day for 7 days so daysUntil counts stay correct
        // without needing the app to be in the foreground.
        var entries: [BirthdayEntry] = []
        for offset in 0..<7 {
            guard let entryDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let upcoming = WidgetDataManager.adjustedBirthdays(from: stored, dayOffset: offset)
            entries.append(BirthdayEntry(date: entryDate, upcomingBirthdays: upcoming))
        }
        if entries.isEmpty {
            entries = [BirthdayEntry(date: today, upcomingBirthdays: [])]
        }

        // After 7 days the stored data is too stale; the app should have refreshed it by then.
        let afterWeek = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let timeline = Timeline(entries: entries, policy: .after(afterWeek))
        completion(timeline)
    }
}

// MARK: - Helpers

private func dayLabel(_ birthday: WidgetBirthday) -> String {
    birthday.isBirthdayToday ? "Today" : "in \(birthday.daysUntil)d"
}

private func nameList(_ birthdays: [WidgetBirthday]) -> String {
    switch birthdays.count {
    case 1: return birthdays[0].name
    case 2: return "\(birthdays[0].name) & \(birthdays[1].name)"
    default:
        let extra = birthdays.count - 1
        return "\(birthdays[0].name) +\(extra)"
    }
}

// MARK: - Widget Views

struct BirthdayWidgetEntryView: View {
    var entry: BirthdayProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SystemSmallView(entry: entry)
        }
    }
}

// MARK: Lock screen – circular

struct AccessoryCircularView: View {
    let entry: BirthdayEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            let nearest = entry.nearestDay
            if nearest.isEmpty {
                // No birthdays this week – show a plain cake outline
                VStack(spacing: 1) {
                    Image(systemName: "birthday.cake")
                        .font(.system(size: 18))
                    Text("7 days")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
            } else if nearest[0].isBirthdayToday {
                // Birthday today – cake icon + name or count
                VStack(spacing: 1) {
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentColor)
                    Text(nearest.count > 1 ? "×\(nearest.count)" : (nearest[0].name.components(separatedBy: " ").first ?? nearest[0].name))
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                }
            } else {
                // Upcoming birthday – cake icon + day count
                VStack(spacing: 1) {
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                    Text("\(nearest[0].daysUntil)d")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

// MARK: Lock screen – rectangular

struct AccessoryRectangularView: View {
    let entry: BirthdayEntry

    var body: some View {
        let nearest = entry.nearestDay
        VStack(alignment: .leading, spacing: 2) {
            // Header row – always visible icon
            HStack(spacing: 4) {
                Image(systemName: "birthday.cake.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                Text(WidgetDataManager.widgetSectionLabel(nearest: nearest))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if nearest.isEmpty {
                // nothing more to show
            } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(nearest.prefix(3)) { birthday in
                    HStack(alignment: .center, spacing: 5) {
                        Text(birthday.name)
                            .font(.caption)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if birthday.isBirthdayToday {
                            Image(systemName: "birthday.cake.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text("\(birthday.daysUntil)d")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if nearest.count > 3 {
                    Text("+\(nearest.count - 3) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: Lock screen – inline

struct AccessoryInlineView: View {
    let entry: BirthdayEntry

    var body: some View {
        let nearest = entry.nearestDay
        if nearest.isEmpty {
            Label("No birthdays in 7 days", systemImage: "gift")
        } else if nearest[0].isBirthdayToday {
            Label("\(nameList(nearest)) · Today!", systemImage: "birthday.cake.fill")
        } else {
            Label("\(nameList(nearest)) · \(dayLabel(nearest[0]))", systemImage: "gift")
        }
    }
}

// MARK: Home screen – small

struct SystemSmallView: View {
    let entry: BirthdayEntry

    var body: some View {
        let nearest = entry.nearestDay
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "birthday.cake.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
                Text("Birthdays")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if nearest.isEmpty {
                Spacer()
                Text("No birthdays\nin next 7 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(nearest.prefix(4)) { birthday in
                    HStack(alignment: .center, spacing: 5) {
                        if birthday.isBirthdayToday {
                            Image(systemName: "birthday.cake.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                        } else {
                            Text("\(birthday.daysUntil)d")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24, alignment: .trailing)
                        }
                        Text(birthday.name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                if nearest.count > 4 {
                    Text("+\(nearest.count - 4) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }
}

// MARK: - Widget Configuration

@main
struct BirthdayWidgetBundle: WidgetBundle {
    var body: some Widget {
        BirthdayWidget()
    }
}

struct BirthdayWidget: Widget {
    let kind = "BirthdayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BirthdayProvider()) { entry in
            BirthdayWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Birthdays")
        .description("See upcoming birthdays at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
        ])
    }
}
