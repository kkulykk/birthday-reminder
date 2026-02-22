import SwiftUI
import Contacts

enum TileStyle {
    case today, missed, upcoming, past
}

struct PersonTileView: View {
    let person: Person
    let style: TileStyle

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(person: person, size: 46, ringColor: avatarRingColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.fullName)
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if let dateText = subtitleDateText {
                        Text(dateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let label = ageLabel {
                        Text("·")
                            .font(.subheadline)
                            .foregroundStyle(.quaternary)
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            trailingBadge
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // Pin separator to always start after the avatar so it's consistent
        // regardless of whether the avatar shows a photo or initials text.
        .alignmentGuide(.listRowSeparatorLeading) { d in
            d[.leading] + 46 + 12
        }
    }

    // MARK: - Subtitle date

    private var subtitleDateText: String? {
        guard person.birthdayMonth != nil, person.birthdayDay != nil else { return nil }
        switch style {
        case .today:
            return "Today"
        case .missed:
            return "Yesterday"
        case .upcoming:
            let d = person.daysUntilBirthday
            switch d {
            case 1:     return "Tomorrow"
            case 2...6: return "In \(d) days"
            default:    return fixedDateString
            }
        case .past:
            let d = person.daysSinceLastBirthday
            switch d {
            case 0: return "Today"
            case 1: return "Yesterday"
            default: return "\(d) days ago"
            }
        }
    }

    private var fixedDateString: String? {
        guard let month = person.birthdayMonth, let day = person.birthdayDay else { return nil }
        var c = DateComponents(); c.month = month; c.day = day; c.year = 2000
        guard let d = Calendar.current.date(from: c) else { return "\(month)/\(day)" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    // MARK: - Age label

    private var ageLabel: String? {
        switch style {
        case .past:
            return person.age.map { "Turned \($0)" }
        default:
            return person.turningAge.map { "Turns \($0)" }
        }
    }

    // MARK: - Ring color

    private var avatarRingColor: Color? {
        switch style {
        case .today:            return .orange
        case .missed:           return .red
        case .upcoming, .past:  return nil
        }
    }

    // MARK: - Trailing badge

    /// Uses rolling-year check for past rows; calendar-year for all others.
    private var isCongratulated: Bool {
        style == .past ? person.isCongratulatedOnLastBirthday : person.isCongratulatedThisYear
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if isCongratulated {
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
        case .today:    return "Today 🎂"
        case .missed:   return "Yesterday"
        case .past:     return "Missed"
        case .upcoming:
            let d = person.daysUntilBirthday
            return d == 1 ? "Tomorrow" : "\(d)d"
        }
    }

    private var badgeForeground: Color {
        switch style {
        case .today, .missed, .past: return .white
        case .upcoming:
            return person.daysUntilBirthday <= 7 ? .white : Color(.label)
        }
    }

    private var badgeBackground: Color {
        switch style {
        case .today:    return .orange
        case .missed:   return .red
        case .past:     return Color(.systemGray2)
        case .upcoming:
            let d = person.daysUntilBirthday
            if d == 1  { return .purple }
            if d <= 7  { return .blue }
            return Color(.systemFill)
        }
    }
}

// MARK: - AvatarView

struct AvatarView: View {
    let person: Person
    let size: CGFloat
    var ringColor: Color? = nil

    @State private var contactImage: UIImage? = nil

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                if let ring = ringColor {
                    Circle().strokeBorder(ring, lineWidth: 2.5)
                }
            }
            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
            .task(id: person.contactIdentifier) {
                await loadContactImage()
            }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let image = contactImage {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let data = person.photoData, let img = UIImage(data: data) {
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

    private func loadContactImage() async {
        guard let identifier = person.contactIdentifier else { return }
        let image = await Task.detached(priority: .background) { () -> UIImage? in
            let keys: [CNKeyDescriptor] = [
                CNContactImageDataAvailableKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            guard let contact = try? CNContactStore().unifiedContact(withIdentifier: identifier, keysToFetch: keys),
                  contact.imageDataAvailable,
                  let data = contact.thumbnailImageData else { return nil }
            return UIImage(data: data)
        }.value
        if let image {
            contactImage = image
        }
    }
}
