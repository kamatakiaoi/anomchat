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

        // 2. Asynchronous Fetch & Background Decode for 120Hz smooth scrolling
        isLoading = true
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasFailed = true
                }
                return
            }

            DispatchQueue.global(qos: .userInteractive).async {
                // Downsample using ImageIO to prevent huge memory spikes and lag
                let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
                guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
                    DispatchQueue.main.async { self.isLoading = false; self.hasFailed = true }
                    return
                }

                // 800px max dimension is optimal for chat/explore without pixelation on Retina
                let downsampleOptions = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 800
                ] as CFDictionary

                guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
                    DispatchQueue.main.async { self.isLoading = false; self.hasFailed = true }
                    return
                }

                let finalImage = UIImage(cgImage: downsampledImage)
                
                // Pre-render to prevent main thread decoding lag during scrolling
                let prepared = finalImage.preparingForDisplay() ?? finalImage
                ImageCache.shared.set(prepared, for: url)

                DispatchQueue.main.async {
                    self.loadedImage = prepared
                    self.isLoading = false
                    self.hasFailed = false
                }
            }
        }.resume()
    }
}
