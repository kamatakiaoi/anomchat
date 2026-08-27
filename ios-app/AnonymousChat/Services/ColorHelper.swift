import SwiftUI

public struct ColorHelper {
    public static func colorFromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        if hexSanitized.count == 6 {
            var rgbValue: UInt64 = 0
            Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
            let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x0000FF) / 255.0
            return Color(red: r, green: g, blue: b)
        }
        return Color.blue
    }

    public static func avatarGradient(_ colorStr: String?) -> LinearGradient {
        guard let colorStr = colorStr, !colorStr.isEmpty else {
            return LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        let parts = colorStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 {
            let c1 = colorFromHex(parts[0])
            let c2 = colorFromHex(parts[1])
            return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if parts.count == 1 {
            let c = colorFromHex(parts[0])
            return LinearGradient(colors: [c, c.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
