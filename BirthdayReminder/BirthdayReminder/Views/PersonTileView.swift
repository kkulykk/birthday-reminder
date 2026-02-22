import SwiftUI

enum TileStyle {
    case today, missed, upcoming
}

struct PersonTileView: View {
    let person: Person
    let style: TileStyle

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(person: person, size: 58, ringColor: avatarRingColor)

            VStack(alignment: .leading, spacing: 5) {
                Text(person.fullName)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if let month = person.birthdayMonth, let day = person.birthdayDay {
                        Text(shortDateString(month: month, day: day))
                            .foregroundStyle(.secondary)
                    }
                    if let age = person.age {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("Age \(age)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer(minLength: 8)

            trailingBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private var avatarRingColor: Color? {
        switch style {
        case .today: .orange
        case .missed: .red
        case .upcoming: nil
        }
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if person.isCongratulatedThisYear {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
                .font(.title2)
        } else {
            Text(badgeText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(badgeForeground)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(badgeBackground, in: Capsule())
        }
    }

    private var badgeText: String {
        switch style {
        case .today:   return "Today 🎂"
        case .missed:  return "Yesterday"
        case .upcoming:
            let d = person.daysUntilBirthday
            return d == 1 ? "Tomorrow" : "\(d)d"
        }
    }

    private var badgeForeground: Color {
        switch style {
        case .today, .missed: return .white
        case .upcoming:
            let d = person.daysUntilBirthday
            return d <= 7 ? .white : Color(.label)
        }
    }

    private var badgeBackground: Color {
        switch style {
        case .today:   return .orange
        case .missed:  return .red
        case .upcoming:
            let d = person.daysUntilBirthday
            if d == 1  { return .purple }
            if d <= 7  { return .blue }
            return Color(.systemFill)
        }
    }

    private func shortDateString(month: Int, day: Int) -> String {
        var c = DateComponents(); c.month = month; c.day = day; c.year = 2000
        guard let d = Calendar.current.date(from: c) else { return "\(month)/\(day)" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }
}

// MARK: - AvatarView

struct AvatarView: View {
    let person: Person
    let size: CGFloat
    var ringColor: Color? = nil

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                if let ring = ringColor {
                    Circle().strokeBorder(ring, lineWidth: 2.5)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let data = person.photoData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(person.initials.isEmpty ? "?" : person.initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private var gradientColors: [Color] {
        let palette: [[Color]] = [
            [.blue, .indigo],
            [.purple, .pink],
            [.orange, .red],
            [.green, .teal],
            [.teal, .cyan]
        ]
        return palette[abs(person.fullName.hashValue) % palette.count]
    }
}
