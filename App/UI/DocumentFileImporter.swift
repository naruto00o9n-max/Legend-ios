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
        // Some providers report custom archives/fonts merely as public.data.
        // Content validators in the importer decide validity, not a dynamic UTI.
        let supported=types.contains(.data) ? types:types+[.data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supported, asCopy: true)
        picker.allowsMultipleSelection = multiple
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        picker.view.accessibilityIdentifier = "cookies-document-picker"
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {
        context.coordinator.parent = self
    }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentFilePicker
        private var finished=false
        init(_ parent: DocumentFilePicker) { self.parent = parent }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finished=true;parent.presented = false }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !finished else{return};finished=true
            let completion = parent.completion
            parent.presented = false
            controller.dismiss(animated:true)
            // Deliver after dismissal. Views can then display progress/errors without
            // competing with the system picker presentation.
            DispatchQueue.main.asyncAfter(deadline:.now()+0.35) {
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

/// Destination authentication belongs to the selected Files provider (including
/// the user's Google Drive account), never to a shared application account.
struct DocumentFileExporter:UIViewControllerRepresentable {
    let urls:[URL]
    @Binding var presented:Bool
    var completion:(Bool)->Void
    func makeCoordinator()->Coordinator{Coordinator(self)}
    func makeUIViewController(context:Context)->UIDocumentPickerViewController{
        let picker=UIDocumentPickerViewController(forExporting:urls,asCopy:true);picker.delegate=context.coordinator;picker.shouldShowFileExtensions=true;return picker
    }
    func updateUIViewController(_ controller:UIDocumentPickerViewController,context:Context){context.coordinator.parent=self}
    final class Coordinator:NSObject,UIDocumentPickerDelegate{
        var parent:DocumentFileExporter
        init(_ parent:DocumentFileExporter){self.parent=parent}
        func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController){parent.presented=false;parent.completion(false)}
        func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){parent.presented=false;parent.completion(true)}
    }
}
