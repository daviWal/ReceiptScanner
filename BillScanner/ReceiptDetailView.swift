//
//  ReceiptDetailView.swift
//  BillScanner
//
//  Created by David Walitza on 01.09.2025.
//

import SwiftUI
import PDFKit

/// A detail screen to preview a saved receipt PDF, share it, and delete it.
struct ReceiptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SavedReceiptsViewModel
    let receipt: Receipt

    @State private var showShare = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            if FileManager.default.fileExists(atPath: receipt.fileURL.path) {
                PDFKitRepresentedView(url: receipt.fileURL)
                    .edgesIgnoringSafeArea(.bottom)
            } else {
                ContentUnavailableView(
                    "PDF not found",
                    systemImage: "doc.questionmark",
                    description: Text(receipt.fileName)
                )
            }
        }
        .navigationTitle(receipt.formattedDate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if #available(iOS 16.0, *) {
                    ShareLink(item: receipt.fileURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this receipt?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // Remove from store (and disk if your store does that)
                viewModel.deleteReceipt(receipt)
                // Best-effort removal of the file in case the store doesn't
                try? FileManager.default.removeItem(at: receipt.fileURL)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [receipt.fileURL])
        }
    }
}

// MARK: - PDFKit Wrapper for SwiftUI
struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(url: url)
    }
}

// MARK: - Share Sheet helper (iOS < 16 fallback)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
