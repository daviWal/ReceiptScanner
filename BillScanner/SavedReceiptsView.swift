import SwiftUI
import PDFKit

// MARK: - Receipt Model

struct Receipt: Identifiable, Codable {
    let id: UUID
    let fileName: String      // e.g. "Receipt_1623456789.pdf"
    let date: Date
    let amount: Double

    // Computed URL to the PDF in Documents
    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(fileName)
    }

    // Thumbnail of the first page
    var thumbnail: UIImage? {
        guard let document = PDFDocument(url: fileURL),
              let page = document.page(at: 0) else {
            return nil
        }
        return page.thumbnail(of: CGSize(width: 60, height: 80), for: .cropBox)
    }

    // Formatted date/time and amount
    var formattedDate: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
    var formattedTime: String {
        let tf = DateFormatter()
        tf.timeStyle = .short
        return tf.string(from: date)
    }
    var formattedAmount: String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        return nf.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - ReceiptStore

class ReceiptStore: ObservableObject {
    @Published var receipts: [Receipt] = []

    private let storeURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("receipts.json")
    }()

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        if let decoded = try? JSONDecoder().decode([Receipt].self, from: data) {
            receipts = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(receipts) {
            try? data.write(to: storeURL)
        }
    }

    func add(_ receipt: Receipt) {
        receipts.append(receipt)
        save()
    }
}

// MARK: - SavedReceiptsView

struct SavedReceiptsView: View {
    @StateObject private var store = ReceiptStore()

    var body: some View {
        List(store.receipts) { receipt in
            ReceiptRow(receipt: receipt)
        }
        .listStyle(PlainListStyle())
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
        let store = ReceiptStore()
        store.receipts = [dummy]
        return NavigationStack {
            SavedReceiptsView()
        }
    }
}
