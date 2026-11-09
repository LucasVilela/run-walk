import Foundation
import RunKit
import UserNotifications

/// Run-day reminders and the one "missed run" nudge, as local notifications.
/// The plan comes from `Reminders.plan` (pure, tested); this just replaces what's scheduled.
@MainActor
final class ReminderNotifications {
    static let shared = ReminderNotifications()
    private static let prefix = "reminder-"
    private let center = UNUserNotificationCenter.current()
    private var update: Task<Void, Never>?

    /// The latest call wins: an earlier update still running is cancelled.
    func replace(with reminders: [PlannedReminder], calendar: Calendar) {
        update?.cancel()
        update = Task { [center] in
            let pending = await center.pendingNotificationRequests().map(\.identifier)
            center.removePendingNotificationRequests(
                withIdentifiers: pending.filter { $0.hasPrefix(Self.prefix) })
            for (i, reminder) in reminders.enumerated() {
                guard !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.body = reminder.body
                content.sound = .default
                let parts = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: reminder.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                try? await center.add(
                    UNNotificationRequest(
                        identifier: "\(Self.prefix)\(i)", content: content, trigger: trigger))
            }
        }
    }
}
