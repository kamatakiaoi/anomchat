import SwiftUI
import UniformTypeIdentifiers

public struct DocumentPicker: UIViewControllerRepresentable {
    public var allowedContentTypes: [UTType] = [.movie, .audio, .data]
    public var onPick: (URL) -> Void
    @Environment(\.presentationMode) private var presentationMode

    public init(allowedContentTypes: [UTType] = [.movie, .audio, .data], onPick: @escaping (URL) -> Void) {
        self.allowedContentTypes = allowedContentTypes
        self.onPick = onPick
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.presentationMode.wrappedValue.dismiss()
            guard let url = urls.first else { return }

            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Create temporary copy to guarantee persistence and sandbox safety
            let fileExtension = url.pathExtension.isEmpty ? "tmp" : url.pathExtension
            let tempDir = FileManager.default.temporaryDirectory
            let tempUrl = tempDir.appendingPathComponent(UUID().uuidString + "." + fileExtension)

            do {
                if FileManager.default.fileExists(atPath: tempUrl.path) {
                    try FileManager.default.removeItem(at: tempUrl)
                }
                try FileManager.default.copyItem(at: url, to: tempUrl)
                parent.onPick(tempUrl)
            } catch {
                // Fallback to original URL
                parent.onPick(url)
            }
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
