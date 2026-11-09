import Foundation
import RunKit
import UserNotifications

/// Local-notification fallback for segment switches, for when the app can't run in the background
/// with the phone locked. One notification per remaining switch, with the
/// app's beep. Rescheduled on start, resume, skip and speed changes; cancelled on pause and end.
/// While the app is in the foreground the delegate hides them, so cues never play twice.
@MainActor
final class CueNotifications: NSObject {
    static let shared = CueNotifications()
    nonisolated static let prefix = "cue-"

    private let center = UNUserNotificationCenter.current()

    /// Call once at launch, before any notification can arrive. No run is active at launch, so any cue
    /// left over from a run that was killed or discarded is removed (a resumed run reschedules its own).
    func install() {
        center.delegate = self
        let ids = (0...Self.maxSegments).map(Self.id)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// More than any workout has (the longest has 18 segments).
    private static let maxSegments = 64

    /// Treadmill cues need notification permission even when reminders are off. Asks once, never again.
    func requestPermissionIfNeeded() async {
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(plan: RunPlan, position: Double, speed: Double) {
        cancelAll(plan: plan)
        for cue in CueSchedule.upcoming(in: plan, position: position) {
            let text = CueSchedule.text(for: cue.index, in: plan)
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = UNNotificationSound(named: UNNotificationSoundName("beep-long.wav"))
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, cue.secondsFromNow / max(speed, 1)), repeats: false)
            center.add(
                UNNotificationRequest(identifier: Self.id(cue.index), content: content, trigger: trigger))
        }
    }

    /// The app announced this switch itself.
    func announced(index: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.id(index)])
    }

    func cancelAll(plan: RunPlan) {
        let ids = (0...plan.segments.count).map(Self.id)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private static func id(_ index: Int) -> String { "\(prefix)\(index)" }
}

extension CueNotifications: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // In the foreground the app's own voice and beeps do the job.
        notification.request.identifier.hasPrefix(CueNotifications.prefix) ? [] : [.banner, .sound]
    }
}
