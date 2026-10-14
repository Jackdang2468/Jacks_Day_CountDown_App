import EventKit
import EventKitUI
import SwiftUI

/// Shows Apple's "New Event" sheet, pre-filled from the countdown. The user
/// picks the calendar (their Outlook / Exchange account if it is on the
/// phone), and the event syncs to Outlook from there. On iOS 17+ this sheet
/// needs no calendar permission because the system adds the event itself.
struct AddToCalendarSheet: UIViewControllerRepresentable {
    let countdown: Countdown
    var onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = countdown.title
        event.notes = countdown.notes.isEmpty ? nil : countdown.notes
        event.isAllDay = countdown.isAllDay
        if countdown.isAllDay {
            let start = Calendar.current.startOfDay(for: countdown.targetDate)
            event.startDate = start
            event.endDate = start
        } else {
            event.startDate = countdown.targetDate
            event.endDate = countdown.targetDate.addingTimeInterval(60 * 60)
        }
        event.addAlarm(EKAlarm(relativeOffset: -24 * 60 * 60))
        if countdown.repeatsYearly {
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil))
        }

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish(action == .saved)
        }
    }
}

/// Builds a standard .ics file, which Outlook (desktop, web, or mobile) can
/// open from Mail, Files, or the share sheet.
enum ICSFile {
    static func make(for countdown: Countdown) -> URL? {
        let utc = DateFormatter()
        utc.calendar = Calendar(identifier: .gregorian)
        utc.locale = Locale(identifier: "en_US_POSIX")
        utc.timeZone = TimeZone(identifier: "UTC")
        utc.dateFormat = "yyyyMMdd'T'HHmmss'Z'"

        let day = DateFormatter()
        day.calendar = Calendar(identifier: .gregorian)
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyyMMdd"

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Jack's Day Counter//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "BEGIN:VEVENT",
            "UID:\(countdown.id.uuidString)@jacksdaycounter",
            "DTSTAMP:\(utc.string(from: .now))",
            "SUMMARY:\(escape(countdown.title))",
        ]
        if countdown.isAllDay {
            let start = Calendar.current.startOfDay(for: countdown.targetDate)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            lines.append("DTSTART;VALUE=DATE:\(day.string(from: start))")
            lines.append("DTEND;VALUE=DATE:\(day.string(from: end))")
        } else {
            lines.append("DTSTART:\(utc.string(from: countdown.targetDate))")
            lines.append("DTEND:\(utc.string(from: countdown.targetDate.addingTimeInterval(3600)))")
        }
        if countdown.repeatsYearly {
            lines.append("RRULE:FREQ=YEARLY")
        }
        if !countdown.notes.isEmpty {
            lines.append("DESCRIPTION:\(escape(countdown.notes))")
        }
        lines += [
            "BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:\(escape(countdown.title))",
            "TRIGGER:-P1D", "END:VALARM",
            "END:VEVENT", "END:VCALENDAR",
        ]

        let safeName = countdown.title.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent((safeName.isEmpty ? "Countdown" : safeName) + ".ics")
        do {
            try lines.joined(separator: "\r\n").appending("\r\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
