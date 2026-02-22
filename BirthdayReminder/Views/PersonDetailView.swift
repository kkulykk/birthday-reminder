import SwiftUI
import SwiftData
import MessageUI

// MARK: - Messaging App

private enum MessagingApp: CaseIterable, Identifiable {
    case iMessage, whatsApp, telegram, viber, signal

    var id: Self { self }

    var displayName: String {
        switch self {
        case .iMessage:  return "iMessage"
        case .whatsApp:  return "WhatsApp"
        case .telegram:  return "Telegram"
        case .viber:     return "Viber"
        case .signal:    return "Signal"
        }
    }

    var icon: String {
        switch self {
        case .iMessage:  return "message.fill"
        case .whatsApp:  return "phone.bubble.fill"
        case .telegram:  return "paperplane.fill"
        case .viber:     return "video.bubble.fill"
        case .signal:    return "lock.shield.fill"
        }
    }

    var urlScheme: String? {
        switch self {
        case .iMessage:  return nil           // handled via MFMessageComposeViewController
        case .whatsApp:  return "whatsapp://"
        case .telegram:  return "tg://"
        case .viber:     return "viber://"
        case .signal:    return "sgnl://"
        }
    }

    func isAvailable(canSendText: Bool) -> Bool {
        switch self {
        case .iMessage:
            return canSendText
        default:
            guard let scheme = urlScheme, let url = URL(string: scheme) else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    func openURL(phone: String) -> URL? {
        let intlPhone = phone.filter { $0.isNumber || $0 == "+" }
        let digitsOnly = phone.filter { $0.isNumber }
        let encoded = "Happy Birthday! 🎂"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        switch self {
        case .iMessage:
            return nil  // handled separately
        case .whatsApp:
            return URL(string: "whatsapp://send?phone=\(digitsOnly)&text=\(encoded)")
        case .telegram:
            return URL(string: "tg://resolve?phone=\(intlPhone)")
        case .viber:
            return URL(string: "viber://contact?number=\(intlPhone)")
        case .signal:
            return URL(string: "sgnl://signal.me/#p/\(intlPhone)")
        }
    }
}

// MARK: - PersonDetailView

struct PersonDetailView: View {
    @Bindable var person: Person
    var style: TileStyle = .upcoming

    @Environment(\.modelContext) private var modelContext

    @State private var showMessage = false
    @State private var showCallConfirm = false
    @State private var showMessagingPicker = false

    private let canSendText = MFMessageComposeViewController.canSendText()
    private let notificationService = NotificationService()

    private var availableMessagingApps: [MessagingApp] {
        MessagingApp.allCases.filter { $0.isAvailable(canSendText: canSendText) }
    }

    private var hasAnyMessagingOption: Bool {
        person.phoneNumber != nil && !availableMessagingApps.isEmpty
    }

    /// Whether to show the congratulate toggle (today, missed-yesterday, or any past entry)
    private var showActionButtons: Bool {
        person.isBirthdayToday || person.isMissedYesterday || style == .past
    }

    /// Whether the person is considered congratulated for this viewing context
    private var isConsideredCongratulated: Bool {
        style == .past ? person.isCongratulatedOnLastBirthday : person.isCongratulatedThisYear
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroHeader
                statsRow
                if showActionButtons {
                    actionButtons
                }
                wishlistRow
                notesRow
            }
            .padding(.bottom, 40)
        }
        .navigationTitle(person.givenName.isEmpty ? person.fullName : person.givenName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMessage) {
            if let phone = person.phoneNumber {
                MessageComposeView(recipient: phone, body: "Happy Birthday! 🎂")
            }
        }
        .confirmationDialog(
            "Send birthday wishes to \(person.givenName.isEmpty ? person.fullName : person.givenName)",
            isPresented: $showMessagingPicker,
            titleVisibility: .visible
        ) {
            ForEach(availableMessagingApps) { app in
                Button(app.displayName) {
                    if app == .iMessage {
                        showMessage = true
                    } else if let phone = person.phoneNumber, let url = app.openURL(phone: phone) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Call \(person.fullName)?", isPresented: $showCallConfirm, titleVisibility: .visible) {
            if let phone = person.phoneNumber {
                Button("Call \(phone)") { makeCall(phone: phone) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 14) {
            AvatarView(person: person, size: 110, ringColor: heroRingColor)

            VStack(spacing: 6) {
                Text(person.fullName)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(person.birthdayDisplayString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                countdownChip
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.horizontal)
    }

    private var heroRingColor: Color? {
        if person.isBirthdayToday { return .orange }
        if person.isMissedYesterday { return .red }
        return nil
    }

    @ViewBuilder
    private var countdownChip: some View {
        if person.isBirthdayToday {
            Label("Birthday Today!", systemImage: "birthday.cake.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange, in: Capsule())
        } else if person.isMissedYesterday {
            Text("Missed — Yesterday")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red, in: Capsule())
        } else if style == .past {
            let d = person.daysSinceLastBirthday
            let label = d == 1 ? "1 day ago" : "\(d) days ago"
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.secondary.opacity(0.12), in: Capsule())
        } else {
            let days = person.daysUntilBirthday
            if days > 0 {
                let label = days == 1 ? "Tomorrow" : "In \(days) days"
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        if style == .past {
            // Past context: show the age they turned and how many days ago
            let daysAgo = person.daysSinceLastBirthday
            if person.age != nil || daysAgo > 0 {
                HStack(spacing: 12) {
                    if let age = person.age {
                        statCard(value: "\(age)", label: "Turned", color: .blue)
                    }
                    if daysAgo > 0 {
                        statCard(value: "\(daysAgo)", label: daysAgo == 1 ? "Day Ago" : "Days Ago", color: .purple)
                    }
                }
                .padding(.horizontal)
            }
        } else {
            // Upcoming / today / missed context
            let ta = person.turningAge
            let days = person.daysUntilBirthday
            if ta != nil || days > 0 {
                HStack(spacing: 12) {
                    if let ta {
                        let ageLabel = person.isBirthdayToday ? "Turning Today" : "Turns"
                        statCard(value: "\(ta)", label: ageLabel, color: .blue)
                    }
                    if !person.isBirthdayToday && days > 0 {
                        statCard(value: "\(days)", label: days == 1 ? "Day Away" : "Days Away", color: .purple)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Message + Call: only shown on the actual birthday or missed-yesterday
            if person.phoneNumber != nil && (person.isBirthdayToday || person.isMissedYesterday) {
                HStack(spacing: 10) {
                    if hasAnyMessagingOption {
                        actionButton("Message", icon: "message.fill", color: .green) {
                            if availableMessagingApps.count == 1, let only = availableMessagingApps.first {
                                if only == .iMessage {
                                    showMessage = true
                                } else if let phone = person.phoneNumber, let url = only.openURL(phone: phone) {
                                    UIApplication.shared.open(url)
                                }
                            } else {
                                showMessagingPicker = true
                            }
                        }
                    }
                    actionButton("Call", icon: "phone.fill", color: .blue) {
                        showCallConfirm = true
                    }
                }
            }

            Button { toggleCongratulated() } label: {
                HStack {
                    Image(systemName: isConsideredCongratulated ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                    Text(isConsideredCongratulated ? "Congratulated!" : "Mark Congratulated")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .foregroundStyle(isConsideredCongratulated ? .green : .primary)
            }
            .glassEffect(in: .rect(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Wishlist Row

    private var wishlistRow: some View {
        NavigationLink(destination: WishlistView(person: person)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.pink.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.pink)
                        .font(.system(size: 17))
                }
                Text("Wishlist")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                let count = person.wishlistItems.count
                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesRow: some View {
        if let notes = person.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Notes", systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    // MARK: - Logic

    private func toggleCongratulated() {
        if isConsideredCongratulated {
            // Undo: clear congratulation
            person.congratulatedYear = nil
        } else if style == .past {
            // Mark past birthday as congratulated — use the year of last birthday
            person.congratulatedYear = Calendar.current.component(.year, from: person.lastBirthdayDate)
        } else {
            // Mark today / missed as congratulated
            person.congratulatedYear = Calendar.current.component(.year, from: Date())
            notificationService.cancelNotification(for: person.id)
        }
        try? modelContext.save()
        Task {
            let people = (try? modelContext.fetch(.init())) ?? [] as [Person]
            await notificationService.rescheduleAll(people: people)
        }
    }

    private func makeCall(phone: String) {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Message Compose

struct MessageComposeView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = [recipient]
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}
