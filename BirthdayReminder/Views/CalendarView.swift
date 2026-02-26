import SwiftUI
import SwiftData

// MARK: - Logic

enum CalendarViewLogic {

    /// Returns 42 slots (6 rows × 7 cols). nil = empty padding cell.
    static func gridDates(for month: Date, calendar: Calendar = .current) -> [Date?] {
        var comps = calendar.dateComponents([.year, .month], from: month)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return Array(repeating: nil, count: 42)
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        var slots: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            var dc = comps
            dc.day = day
            slots.append(calendar.date(from: dc))
        }
        while slots.count < 42 {
            slots.append(nil)
        }
        return slots
    }

    static func nextMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: 1, to: date) ?? date
    }

    static func previousMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -1, to: date) ?? date
    }

    enum SwipeDirection { case forward, backward, none }

    /// Maps a horizontal drag translation to a navigation direction.
    /// A negative translation (left swipe) moves forward; positive moves backward.
    static func swipeDirection(from translation: CGFloat, threshold: CGFloat = 50) -> SwipeDirection {
        if translation < -threshold { return .forward }
        if translation > threshold { return .backward }
        return .none
    }

    /// Returns non-excluded people with a birthday on the given month/day.
    static func birthdayPeople(inMonth month: Int, onDay day: Int, from people: [Person]) -> [Person] {
        people.filter { p in
            !p.isExcluded
            && p.birthdayMonth == month
            && p.birthdayDay == day
        }
    }
}

// MARK: - View

struct CalendarView: View {
    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    @State private var selectedDay: Int? = Calendar.current.component(.day, from: Date())

    @Query private var allPeople: [Person]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                    .padding(.horizontal)
                    .padding(.top, 8)

                dayOfWeekRow
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(CalendarViewLogic.gridDates(for: displayedMonth).enumerated()), id: \.offset) { _, slot in
                        if let date = slot {
                            let day = Calendar.current.component(.day, from: date)
                            let month = Calendar.current.component(.month, from: date)
                            let hasBirthdays = !CalendarViewLogic.birthdayPeople(
                                inMonth: month, onDay: day, from: allPeople
                            ).isEmpty
                            DayCell(
                                day: day,
                                isToday: Calendar.current.isDateInToday(date),
                                isSelected: selectedDay == day,
                                hasBirthdays: hasBirthdays
                            )
                            .onTapGesture { selectedDay = day }
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            switch CalendarViewLogic.swipeDirection(from: value.translation.width) {
                            case .forward:
                                displayedMonth = CalendarViewLogic.nextMonth(displayedMonth)
                                selectedDay = nil
                            case .backward:
                                displayedMonth = CalendarViewLogic.previousMonth(displayedMonth)
                                selectedDay = nil
                            case .none:
                                break
                            }
                        }
                )
                .padding(.horizontal, 4)

                Divider()
                    .padding(.top, 8)

                birthdayList
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Subviews

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = CalendarViewLogic.previousMonth(displayedMonth)
                selectedDay = nil
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthTitle)
                .font(.headline)

            Spacer()

            Button {
                displayedMonth = CalendarViewLogic.nextMonth(displayedMonth)
                selectedDay = nil
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var dayOfWeekRow: some View {
        HStack(spacing: 0) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var birthdayList: some View {
        let month = Calendar.current.component(.month, from: displayedMonth)
        let people: [Person] = selectedDay.map {
            CalendarViewLogic.birthdayPeople(inMonth: month, onDay: $0, from: allPeople)
        } ?? []

        let headerText: String = {
            guard let day = selectedDay else { return "No birthdays" }
            var comps = DateComponents()
            comps.month = month
            comps.day = day
            comps.year = 2000
            if let d = Calendar.current.date(from: comps) {
                let fmt = DateFormatter()
                fmt.dateFormat = "MMM d"
                return fmt.string(from: d)
            }
            return "\(month)/\(day)"
        }()

        List {
            Section(header: Text(headerText)) {
                if people.isEmpty {
                    Text(selectedDay == nil ? "Select a day to see birthdays." : "No birthdays on this day.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(people) { person in
                        NavigationLink(destination: PersonDetailView(person: person, style: tileStyle(for: person))) {
                            PersonTileView(person: person, style: tileStyle(for: person))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayedMonth)
    }

    private func tileStyle(for person: Person) -> TileStyle {
        if person.isBirthdayToday { return .today }
        if person.isMissedYesterday { return .missed }
        if (person.daysSinceBirthday ?? -1) > 0 { return .past }
        return .upcoming
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let hasBirthdays: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 32, height: 32)
                Text("\(day)")
                    .font(.callout)
                    .foregroundStyle(textColor)
            }
            Circle()
                .fill(hasBirthdays ? Color.orange : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }

    private var circleColor: Color {
        if isToday { return .blue }
        if isSelected { return Color(.systemGray5) }
        return .clear
    }

    private var textColor: Color {
        if isToday { return .white }
        return .primary
    }
}
