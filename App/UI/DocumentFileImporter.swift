import SwiftUI
import UniformTypeIdentifiers

/// UIKit owns the Files selection lifecycle. Import mode copies provider files
/// into the application sandbox before delivery (including iCloud documents).
struct DocumentFilePicker: UIViewControllerRepresentable {
    let types: [UTType]
    let multiple: Bool
    @Binding var presented: Bool
    let completion: (Result<[URL], Error>) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = multiple
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {
        context.coordinator.parent = self
    }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentFilePicker
        init(_ parent: DocumentFilePicker) { self.parent = parent }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { parent.presented = false }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let completion = parent.completion
            parent.presented = false
            // Deliver after dismissal. Views can then display progress/errors without
            // competing with the system picker presentation.
            DispatchQueue.main.async {
                if urls.isEmpty { completion(.failure(ImageFailure.message("لم يُحدد ملف للاستيراد"))) }
                else { completion(.success(urls)) }
            }
        }
    }
}
extension View {
    func cookiesFileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, onCompletion: @escaping (Result<[URL], Error>) -> Void) -> some View {
        sheet(isPresented: isPresented) {
            DocumentFilePicker(types: allowedContentTypes, multiple: allowsMultipleSelection, presented: isPresented, completion: onCompletion).ignoresSafeArea()
        }
    }
    func cookiesFileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        cookiesFileImporter(isPresented: isPresented, allowedContentTypes: allowedContentTypes, allowsMultipleSelection: false) { result in
            onCompletion(result.flatMap { urls in
                guard let url = urls.first else { return .failure(ImageFailure.message("لم يُحدد ملف للاستيراد")) }
                return .success(url)
            })
        }
    }
}
