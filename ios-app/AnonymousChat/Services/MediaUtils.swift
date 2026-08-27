import UIKit
import AVFoundation

public struct MediaUtils {
    public static func getFullMediaUrl(serverBaseUrl: String, mediaPath: String?) -> URL? {
        guard var path = mediaPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }

        var cleanBase = serverBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBase.isEmpty {
            cleanBase = "http://snow.pikamc.vn:25222"
        }
        if !cleanBase.hasPrefix("http://") && !cleanBase.hasPrefix("https://") {
            cleanBase = "http://" + cleanBase
        }
        while cleanBase.hasSuffix("/") {
            cleanBase.removeLast()
        }

        var fullUrlString: String
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            fullUrlString = path
        } else {
            if !path.hasPrefix("/") {
                path = "/" + path
            }
            if !path.hasPrefix("/uploads/") && !path.hasPrefix("/api/") {
                path = "/uploads" + path
            }
            fullUrlString = cleanBase + path
        }

        if let validUrl = URL(string: fullUrlString) {
            return validUrl
        }

        let allowed = CharacterSet.urlQueryAllowed.union(CharacterSet(charactersIn: "%#[]"))
        if let encoded = fullUrlString.addingPercentEncoding(withAllowedCharacters: allowed) {
            return URL(string: encoded)
        }

        return nil
    }

    public static func compressImageToBase64(_ image: UIImage, maxDimension: CGFloat = 1200, quality: CGFloat = 0.8) -> String? {
        autoreleasepool {
            let size = image.size
            let maxSide = max(size.width, size.height)
            var targetSize = size
            if maxSide > maxDimension {
                let ratio = maxDimension / maxSide
                targetSize = CGSize(width: max(1, size.width * ratio), height: max(1, size.height * ratio))
            }

            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }

            guard let jpegData = resizedImage.jpegData(compressionQuality: quality) else {
                return nil
            }
            return "data:image/jpeg;base64," + jpegData.base64EncodedString()
        }
    }

    public static func fileDataToBase64(url: URL, mimeType: String? = nil) -> String? {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return autoreleasepool {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                return nil
            }
            // 50MB limit matching server.js max limit
            if data.count > 50 * 1024 * 1024 { return nil }

            let mime = mimeType ?? mimeTypeForExtension(url.pathExtension)
            return "data:\(mime);base64," + data.base64EncodedString()
        }
    }

    public static func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "webm": return "video/webm"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "m4a", "aac": return "audio/mp4" // server.js regex matches audio/(mpeg|mp3|ogg|wav|webm|mp4) and maps mp4 -> m4a
        case "ogg": return "audio/ogg"
        default: return "video/mp4"
        }
    }
}
