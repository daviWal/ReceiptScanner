// MARK: - Receipt Model

import Foundation
import UIKit
import PDFKit

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
