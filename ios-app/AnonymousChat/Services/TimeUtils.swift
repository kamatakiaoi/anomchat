import Foundation

public struct TimeUtils {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let fallbackFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return f
    }()

    private static let fallbackShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()

    public static func parseDate(_ isoString: String) -> Date? {
        if let d = isoFormatter.date(from: isoString) { return d }
        if let d = fallbackFormatter.date(from: isoString) { return d }
        if let d = fallbackShortFormatter.date(from: isoString) { return d }
        return nil
    }

    public static func formatMessageTime(_ isoString: String, timezone: String = "vn") -> String {
        guard let date = parseDate(isoString) else { return isoString }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        if timezone == "vn" {
            formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? TimeZone(secondsFromGMT: 7 * 3600)
        } else {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
        }
        return formatter.string(from: date)
    }

    public static func formatRelativeTime(_ isoString: String) -> String {
        guard let date = parseDate(isoString) else { return "" }
        let now = Date()
        let diff = Int(now.timeIntervalSince(date))
        if diff < 10 { return "just now" }
        if diff < 60 { return "\(diff)s ago" }
        let mins = diff / 60
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 30 { return "\(days)d ago" }
        return formatMessageTime(isoString)
    }
}
