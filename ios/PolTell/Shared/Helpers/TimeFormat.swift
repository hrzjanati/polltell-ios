import Perception
import SwiftUI
import PolTellCore

/// "Today 13:20" / "Yesterday 09:05" / "Mon 13:20" / "12 Nov 2026 at 13:20", as Messages writes it.
func transcriptTime(_ ms: Int64) -> String {
    let d = Date(millis: ms)
    let cal = Calendar.current
    let time = d.formatted(date: .omitted, time: .shortened)
    if cal.isDateInToday(d) { return String(localized: "Today") + " " + time }
    if cal.isDateInYesterday(d) { return String(localized: "Yesterday") + " " + time }
    if let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: .now)).day, days < 7 {
        return d.formatted(.dateTime.weekday(.abbreviated)) + " " + time
    }
    return d.formatted(.dateTime.day().month(.abbreviated).year()) + " " + time
}

func shortTime(_ ms: Int64) -> String {
    let d = Date(millis: ms)
    if Calendar.current.isDateInToday(d) { return d.formatted(date: .omitted, time: .shortened) }
    if Calendar.current.isDateInYesterday(d) { return String(localized: "Yesterday") }
    return d.formatted(.dateTime.day().month(.abbreviated))
}
