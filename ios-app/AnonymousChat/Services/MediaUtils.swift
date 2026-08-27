import UIKit
import AVFoundation

public struct MediaUtils {
    public static func getFullMediaUrl(serverBaseUrl: String, mediaPath: String?) -> URL? {
        guard var path = mediaPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        var cleanBase = serverBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleanBase.hasSuffix("/") {
            cleanBase.removeLast()
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        if !path.hasPrefix("/uploads/") && !path.hasPrefix("/api/") {
            path = "/uploads" + path
        }
        return URL(string: cleanBase + path)
    }

    public static func compressImageToBase64(_ image: UIImage, maxDimension: CGFloat = 1080, quality: CGFloat = 0.75) -> String? {
        var newSize = image.size
        let maxSide = max(newSize.width, newSize.height)
        if maxSide > maxDimension {
            let scale = maxDimension / maxSide
            newSize = CGSize(width: newSize.width * scale, height: newSize.height * scale)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let resizedImage = resized,
              let jpegData = resizedImage.jpegData(compressionQuality: quality) else {
            return nil
        }
        return "data:image/jpeg;base64," + jpegData.base64EncodedString()
    }

    public static func fileDataToBase64(url: URL, mimeType: String) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if data.count > 50 * 1024 * 1024 { return nil } // 50MB limit matching server.js
        return "data:\(mimeType);base64," + data.base64EncodedString()
    }
}
