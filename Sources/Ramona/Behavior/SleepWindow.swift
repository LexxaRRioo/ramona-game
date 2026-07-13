import Foundation

/// A daily recurring time range like "01:00-08:00", parsed from
/// ramona.json's schedule.sleepHours. Wraps past midnight correctly, so
/// e.g. "22:00-06:00" covers 22:00...23:59 and 00:00...06:00.
struct SleepWindow {
    let startHour: Double
    let endHour: Double

    init?(_ text: String) {
        let parts = text.split(separator: "-")
        guard parts.count == 2,
              let start = Self.hour(from: String(parts[0])),
              let end = Self.hour(from: String(parts[1])) else { return nil }
        startHour = start
        endHour = end
    }

    func contains(hour: Double) -> Bool {
        if startHour <= endHour {
            return hour >= startHour && hour < endHour
        } else {
            return hour >= startHour || hour < endHour
        }
    }

    private static func hour(from text: String) -> Double? {
        let components = text.split(separator: ":")
        guard components.count == 2,
              let h = Double(components[0]), let m = Double(components[1]) else { return nil }
        return h + m / 60
    }
}
