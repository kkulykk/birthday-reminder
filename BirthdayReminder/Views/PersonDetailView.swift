import SwiftUI
import SwiftData
import MessageUI

struct PersonDetailView: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var modelContext

    @State private var showMessage = false
    @State private var showCallConfirm = false
    private let canSendText = MFMessageComposeViewController.canSendText()
    private let notificationService = NotificationService()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroHeader
                statsRow
                actionButtons
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
        let age = person.age
        let days = person.daysUntilBirthday
        if age != nil || days > 0 {
            HStack(spacing: 12) {
                if let age {
                    statCard(value: "\(age)", label: "Years Old", color: .blue)
                }
                if !person.isBirthdayToday && days > 0 {
                    statCard(value: days == 1 ? "1" : "\(days)", label: days == 1 ? "Day Away" : "Days Away", color: .purple)
                }
            }
            .padding(.horizontal)
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
            if person.phoneNumber != nil {
                HStack(spacing: 10) {
                    if canSendText {
                        actionButton("Message", icon: "message.fill", color: .green) {
                            showMessage = true
                        }
                    }
                    actionButton("Call", icon: "phone.fill", color: .blue) {
                        showCallConfirm = true
                    }
                }
            }

            Button { toggleCongratulated() } label: {
                HStack {
                    Image(systemName: person.isCongratulatedThisYear ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                    Text(person.isCongratulatedThisYear ? "Congratulated!" : "Mark Congratulated")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .foregroundStyle(person.isCongratulatedThisYear ? .green : .primary)
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
        let currentYear = Calendar.current.component(.year, from: Date())
        if person.isCongratulatedThisYear {
            person.congratulatedYear = nil
        } else {
            person.congratulatedYear = currentYear
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
