import SwiftUI
import ImageIO

public class ImageCache {
    public static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB memory limit
    }

    public func get(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    public func set(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    public let url: URL?
    public let content: (Image) -> Content
    public let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = false
    @State private var hasFailed: Bool = false

    public init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    public var body: some View {
        Group {
            if let uiImage = loadedImage {
                content(Image(uiImage: uiImage))
            } else if hasFailed {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { newUrl in
            loadedImage = nil
            hasFailed = false
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        // 1. Instant Memory Cache Check
        if let cached = ImageCache.shared.get(for: url) {
            self.loadedImage = cached
            return
        }

        isLoading = true

        // 2. Handle Data URI directly (base64 image)
        if url.scheme == "data" || url.absoluteString.hasPrefix("data:") {
            DispatchQueue.global(qos: .userInteractive).async {
                let urlStr = url.absoluteString
                var data: Data?
                if let commaIdx = urlStr.firstIndex(of: ",") {
                    let b64 = String(urlStr[urlStr.index(after: commaIdx)...])
                    data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
                }
                self.processImageData(data, for: url)
            }
            return
        }

        // 3. Handle local file URL directly
        if url.isFileURL {
            DispatchQueue.global(qos: .userInteractive).async {
                let data = try? Data(contentsOf: url)
                self.processImageData(data, for: url)
            }
            return
        }

        // 4. Remote HTTP/HTTPS Fetch with Cache Policy
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasFailed = true
                }
                return
            }
            DispatchQueue.global(qos: .userInteractive).async {
                self.processImageData(data, for: url)
            }
        }.resume()
    }

    private func processImageData(_ data: Data?, for url: URL) {
        guard let data = data else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.hasFailed = true
            }
            return
        }

        autoreleasepool {
            // Attempt 1: Fast ImageIO Downsampling
            let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            var decodedImage: UIImage?

            if let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) {
                let downsampleOptions = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1000
                ] as CFDictionary

                if let downsampled = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) {
                    decodedImage = UIImage(cgImage: downsampled)
                }
            }

            // Attempt 2: Universal Fallback for WebP, GIF, progressive JPEG
            if decodedImage == nil {
                decodedImage = UIImage(data: data)
            }

            guard let finalImage = decodedImage else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasFailed = true
                }
                return
            }

            let prepared = finalImage.preparingForDisplay() ?? finalImage
            ImageCache.shared.set(prepared, for: url)

            DispatchQueue.main.async {
                self.loadedImage = prepared
                self.isLoading = false
                self.hasFailed = false
            }
        }
    }
}
