import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Own the provider's file before its callback returns; its URL is temporary.
enum PhotoImport {
    static func ownFile(_ url: URL) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoImports/"+UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = url.deletingPathExtension().lastPathComponent
        let target = folder.appendingPathComponent(name).appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: target)
        guard (try target.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
            throw ImageFailure.message("الصورة المختارة فارغة. أعد تنزيلها من iCloud ثم حاول مجددًا.")
        }
        return target
    }
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var multiple = false
    var completion: (Result<[URL], Error>) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = multiple ? 0 : 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ picker: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard !results.isEmpty else { return }
            Task { @MainActor in
                var owned: [URL] = []
                do {
                    for result in results {
                        let provider = result.itemProvider
                        guard let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else {
                            throw ImageFailure.message("تعذر قراءة صيغة الصورة المختارة.")
                        }
                        let url: URL = try await withCheckedThrowingContinuation { continuation in
                            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                                do {
                                    if let error { throw error }
                                    guard let url else { throw ImageFailure.message("لم تُنزّل الصورة من مكتبة الصور.") }
                                    continuation.resume(returning: try PhotoImport.ownFile(url))
                                } catch { continuation.resume(throwing: error) }
                            }
                        }
                        owned.append(url)
                    }
                    parent.completion(.success(owned))
                } catch {
                    owned.forEach { try? FileManager.default.removeItem(at: $0) }
                    parent.completion(.failure(error))
                }
            }
        }
    }
}

struct ArabicTextEditor: UIViewRepresentable {
    @Binding var text: String
    var identifier = "text-input"
    var layer:EditorLayer?=nil
    var selectionChanged:((NSRange)->Void)?=nil
    var requestedSelection:NSRange?=nil
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = .white
        view.font = .systemFont(ofSize: 17)
        view.semanticContentAttribute = .forceRightToLeft
        view.textAlignment = .right
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.alignment = .right
        view.typingAttributes = [.paragraphStyle: paragraph, .font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.white]
        view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.accessibilityIdentifier = identifier
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if let layer,view.markedTextRange==nil {
            let styled=Self.presentation(layer),selection=view.selectedRange
            view.typingAttributes[.foregroundColor]=UIColor.white
            if !view.attributedText.isEqual(to:styled){view.attributedText=styled;view.selectedRange=NSRange(location:min(selection.location,styled.length),length:min(selection.length,max(0,styled.length-selection.location)))}
        }else if view.text != text { view.text = text }
        if view.markedTextRange==nil,let requestedSelection{let count=view.text.utf16.count,location=min(count,max(0,requestedSelection.location));let selection=NSRange(location:location,length:min(max(0,requestedSelection.length),count-location));if view.selectedRange != selection{view.selectedRange=selection}}
    }
    static func presentation(_ layer:EditorLayer)->NSAttributedString {
        let styled=NSMutableAttributedString(attributedString:LayerRenderer.attributed(layer))
        styled.enumerateAttribute(.font,in:NSRange(location:0,length:styled.length)){value,range,_ in if let font=value as? UIFont{styled.addAttribute(.font,value:UIFont(descriptor:font.fontDescriptor,size:min(40,max(8,17*font.pointSize/CGFloat(max(1,layer.style.fontSize))))),range:range)}}
        styled.addAttribute(.foregroundColor,value:UIColor.white,range:NSRange(location:0,length:styled.length))
        return styled
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ArabicTextEditor
        init(_ parent: ArabicTextEditor) { self.parent = parent }
        func textViewDidBeginEditing(_ view:UITextView){if view.text=="نص جديد"{DispatchQueue.main.async{guard view.isFirstResponder,view.text=="نص جديد" else{return};view.selectedRange=NSRange(location:0,length:view.text.utf16.count);self.parent.selectionChanged?(view.selectedRange)}}}
        func textViewDidChange(_ view: UITextView) { parent.text = view.text }
        func textViewDidChangeSelection(_ view:UITextView){parent.selectionChanged?(view.selectedRange)}
    }
}
