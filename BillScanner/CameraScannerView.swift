import SwiftUI
import VisionKit
import PDFKit

struct CameraScannerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: CameraScannerView

        init(parent: CameraScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Combine scanned pages into a single PDF
            let pdfDocument = PDFDocument()
            for pageIndex in 0 ..< scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                if let pdfPage = PDFPage(image: image) {
                    pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                }
            }

            // Save PDF to the app's Documents directory
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "Receipt_\(timestamp).pdf"
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent(fileName)

            if pdfDocument.write(to: fileURL) {
                print("Saved PDF at \(fileURL)")

                // Create a new Receipt model
                let newReceipt = Receipt(
                    id: UUID(),
                    fileName: fileName,
                    date: Date(),
                    amount: 0.0 // you could add parsing later
                )

                // Save into ReceiptStore
                ReceiptStore.shared.add(newReceipt)
            }

            // Dismiss the scanner and go back
            controller.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner error: \(error.localizedDescription)")
            controller.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
