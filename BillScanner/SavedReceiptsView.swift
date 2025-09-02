import SwiftUI
import PDFKit

// MARK: - SavedReceiptsView

struct SavedReceiptsView: View {
    @StateObject private var viewModel: SavedReceiptsViewModel

    init(viewModel: SavedReceiptsViewModel = SavedReceiptsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            ForEach(viewModel.receipts) { receipt in
                NavigationLink(destination: ReceiptDetailView(viewModel: viewModel, receipt: receipt)) {
                    ReceiptRow(receipt: receipt)
                }
            }
            .onDelete { indexSet in
                indexSet.map { viewModel.receipts[$0] }.forEach { receipt in
                    viewModel.deleteReceipt(receipt)
                }
            }
        }
        .listStyle(PlainListStyle())
        .onAppear { viewModel.loadReceipts() }
        .navigationTitle("Saved Bills")
    }
}

// MARK: - ReceiptRow

struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            if let thumb = receipt.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .frame(width: 60, height: 80)
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 60, height: 80)
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.formattedDate)
                    .font(.headline)
                Text(receipt.formattedTime)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Amount: \(receipt.formattedAmount)")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

struct SavedReceiptsView_Previews: PreviewProvider {
    static var previews: some View {
        let dummy = Receipt(
            id: UUID(),
            fileName: "Receipt_1234567890.pdf",
            date: Date(),
            amount: 42.50
        )
        let previewVM = SavedReceiptsViewModel(previewReceipts: [dummy])
        return NavigationStack {
            SavedReceiptsView(viewModel: previewVM)
        }
    }
}
