import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

public struct ImagePicker: UIViewControllerRepresentable {
    @Binding public var selectedImages: [UIImage]
    public var maxSelectionCount: Int = 1
    public var allowVideos: Bool = false
    public var onVideoPicked: ((String) -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode

    public init(
        selectedImages: Binding<[UIImage]>,
        maxSelectionCount: Int = 1,
        allowVideos: Bool = false,
        onVideoPicked: ((String) -> Void)? = nil
    ) {
        self._selectedImages = selectedImages
        self.maxSelectionCount = maxSelectionCount
        self.allowVideos = allowVideos
        self.onVideoPicked = onVideoPicked
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxSelectionCount
        if allowVideos {
            config.filter = .any(of: [.images, .videos])
        } else {
            config.filter = .images
        }

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()

            guard !results.isEmpty else { return }

            for result in results {
                let itemProvider = result.itemProvider

                // 1. Check for Video
                if parent.allowVideos && itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                        guard let self = self, let srcUrl = url else { return }
                        // Create a persistent temp file copy since srcUrl is scoped to this block
                        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + (srcUrl.pathExtension.isEmpty ? "mp4" : srcUrl.pathExtension))
                        try? FileManager.default.copyItem(at: srcUrl, to: tempFile)

                        DispatchQueue.global(qos: .userInitiated).async {
                            if let b64 = MediaUtils.fileDataToBase64(url: tempFile) {
                                DispatchQueue.main.async {
                                    self.parent.onVideoPicked?(b64)
                                }
                            }
                            try? FileManager.default.removeItem(at: tempFile)
                        }
                    }
                    continue
                }

                // 2. Check for Image
                if itemProvider.canLoadObject(ofClass: UIImage.self) {
                    itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                        guard let self = self, let uiImage = image as? UIImage else { return }
                        DispatchQueue.main.async {
                            self.parent.selectedImages.append(uiImage)
                        }
                    }
                }
            }
        }
    }
}
