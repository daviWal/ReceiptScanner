import SwiftUI
import VisionKit
import PDFKit
import Vision

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
            var images: [UIImage] = []
            for pageIndex in 0 ..< scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
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

                let recognizedText = recognizeText(from: images)
                let detectedDate = extractDate(from: recognizedText) ?? Date()
                let (amountOpt, currencyOpt) = extractAmountAndCurrency(from: recognizedText)
                let detectedAmount = amountOpt ?? 0.0
                // TODO: use currencyOpt (e.g., print or store later)
                print("Detected amount: \(detectedAmount) currency: \(currencyOpt ?? "?")")

                let newReceipt = Receipt(
                    id: UUID(),
                    fileName: fileName,
                    date: detectedDate,
                    amount: detectedAmount
                )
                ReceiptStore.shared.add(newReceipt)
            }

            // Dismiss the scanner and go back
            controller.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        private func extractDate(from text: String) -> Date? {
            // Supports: dd.mm.yyyy, dd/mm/yyyy, dd-mm-yyyy, yyyy-mm-dd
            let patterns = [
                #"\b(\d{1,2})[\./-](\d{1,2})[\./-](\d{2,4})\b"#,
                #"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let ns = text as NSString
                    if pattern.hasPrefix("\\b(\\d{4})") {
                        // yyyy-mm-dd
                        let y = ns.substring(with: match.range(at: 1))
                        let m = ns.substring(with: match.range(at: 2))
                        let d = ns.substring(with: match.range(at: 3))
                        let df = DateFormatter()
                        df.locale = Locale(identifier: "en_US_POSIX")
                        df.dateFormat = "yyyy-MM-dd"
                        return df.date(from: "\(y)-\(m.pad2())-\(d.pad2())")
                    } else {
                        // dd.mm.yyyy or dd/mm/yy etc.
                        var d = ns.substring(with: match.range(at: 1))
                        var m = ns.substring(with: match.range(at: 2))
                        var y = ns.substring(with: match.range(at: 3))
                        if y.count == 2 { y = "20" + y }
                        let df = DateFormatter()
                        df.locale = Locale(identifier: "en_US_POSIX")
                        df.dateFormat = "dd-MM-yyyy"
                        return df.date(from: "\(d.pad2())-\(m.pad2())-\(y)")
                    }
                }
            }
            return nil
        }

        private func extractAmount(from text: String) -> Double? {
            // Prefer lines that look like totals
            let keywords = ["total", "amount", "sum", "due", "paid", "gesamt", "celkem", "suma", "razem"]
            let lines = text.split(whereSeparator: { $0.isNewline }).map { String($0) }

            // Regex captures currency and number with possible separators and decimal comma/dot
            // Examples matched: 1 234,50 Kč | €1.234,50 | 1,234.50 EUR | CZK 1234.50 | 1234 Kč
            let pattern = #"""
(?xi)
(?:^|\b)
(?:
    (?:(?<CUR>k\s?c|kč|czk|eur|€|usd|\$|gbp|£)\s*)?
    (?<NUM>\d{1,3}(?:[\s.,]\d{3})*(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)
    \s*(?:(?<CUR2>k\s?c|kč|czk|eur|€|usd|\$|gbp|£))?
)
"""#

            func numberFrom(_ matched: String) -> Double? {
                // Normalize: remove thin spaces, NBSP
                var s = matched.replacingOccurrences(of: "\u{00A0}", with: " ")
                s = s.replacingOccurrences(of: "\u{202F}", with: " ")
                // If both comma and dot exist, decide decimal by last separator
                if s.contains(",") && s.contains(".") {
                    if let lastComma = s.lastIndex(of: ","), let lastDot = s.lastIndex(of: ".") {
                        if lastComma > lastDot {
                            // comma is decimal, dots/spaces are thousand
                            s = s.replacingOccurrences(of: ".", with: "")
                            s = s.replacingOccurrences(of: " ", with: "")
                            s = s.replacingOccurrences(of: ",", with: ".")
                        } else {
                            // dot is decimal, commas/spaces thousand
                            s = s.replacingOccurrences(of: ",", with: "")
                            s = s.replacingOccurrences(of: " ", with: "")
                        }
                    }
                } else if s.contains(",") && !s.contains(".") {
                    // Treat comma as decimal
                    s = s.replacingOccurrences(of: " ", with: "")
                    s = s.replacingOccurrences(of: ",", with: ".")
                } else {
                    // Remove thousand spaces/commas
                    s = s.replacingOccurrences(of: ",", with: "")
                    s = s.replacingOccurrences(of: " ", with: "")
                }
                return Double(s)
            }

            func scanLine(_ line: String) -> [Double] {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
                let ns = line as NSString
                let range = NSRange(location: 0, length: ns.length)
                var results: [Double] = []
                regex.enumerateMatches(in: line, options: [], range: range) { match, _, _ in
                    guard let match = match else { return }
                    let numStr = ns.substring(with: match.range(withName: "NUM"))
                    if let value = numberFrom(numStr) { results.append(value) }
                }
                return results
            }

            // First pass: lines containing total-like keywords
            var candidates: [Double] = []
            for line in lines {
                let lower = line.lowercased()
                if keywords.contains(where: { lower.contains($0) }) {
                    candidates.append(contentsOf: scanLine(line))
                }
            }
            if let best = candidates.max() { return best }

            // Fallback: take the maximum amount anywhere (often total is the largest)
            var all: [Double] = []
            for line in lines { all.append(contentsOf: scanLine(line)) }
            return all.max()
        }

        private func extractAmountAndCurrency(from text: String) -> (Double?, String?) {
            // Positive and negative cues
            let positive = [
                "grand total", "balance due", "amount due", "total due",
                "total", "amount", "sum", "paid", "together",
                "celkem", "suma", "razem", "gesamt", "betrag", "summe", "toplam"
            ]
            let negative = [
                "tax", "vat", "dph", "dp h", "tips", "tip", "gratuity",
                "change", "rounding", "refund", "cashback", "deposit", "points"
            ]

            // Currency map: symbol/code -> ISO-ish label
            let currencyMap: [String:String] = [
                "kč":"CZK","kc":"CZK","czk":"CZK",
                "€":"EUR","eur":"EUR",
                "$":"USD","usd":"USD",
                "£":"GBP","gbp":"GBP",
                "zł":"PLN","zl":"PLN","pln":"PLN",
                "ft":"HUF","huf":"HUF",
                "fr":"CHF","chf":"CHF",
                "kr":"SEK", // could also be DKK/NOK; refine if you localize
                "lei":"RON","ron":"RON",
                "₴":"UAH","uah":"UAH"
            ]

            // Multiline raw regex: optional currency before/after + flexible thousands/decimals
            let pattern = #"""
(?xi)
(?:
  (?:(?<CUR>k\s?c|kč|czk|eur|€|usd|\$|gbp|£|zł|zl|pln|ft|huf|fr|chf|kr|lei|ron|₴|uah)\s*)?
  (?<NUM>\d{1,3}(?:[ \u{00A0}\u{202F}.,]\d{3})*(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)
  \s*(?:(?<CUR2>k\s?c|kč|czk|eur|€|usd|\$|gbp|£|zł|zl|pln|ft|huf|fr|chf|kr|lei|ron|₴|uah))?
)
"""#

            func normalizeNumber(_ sIn: String) -> Double? {
                // remove NBSPs/thin spaces
                var s = sIn.replacingOccurrences(of: "\u{00A0}", with: " ")
                           .replacingOccurrences(of: "\u{202F}", with: " ")
                // Decide decimal sep if both present: whichever occurs last is decimal
                if s.contains(",") && s.contains("."),
                   let lastComma = s.lastIndex(of: ","),
                   let lastDot = s.lastIndex(of: ".") {
                    if lastComma > lastDot {
                        s = s.replacingOccurrences(of: ".", with: "")
                             .replacingOccurrences(of: " ", with: "")
                             .replacingOccurrences(of: ",", with: ".")
                    } else {
                        s = s.replacingOccurrences(of: ",", with: "")
                             .replacingOccurrences(of: " ", with: "")
                    }
                } else if s.contains(",") {
                    s = s.replacingOccurrences(of: " ", with: "")
                         .replacingOccurrences(of: ",", with: ".")
                } else {
                    s = s.replacingOccurrences(of: " ", with: "")
                         .replacingOccurrences(of: ",", with: "")
                }
                return Double(s)
            }

            struct Candidate { let amount: Double; let currency: String?; let score: Int }

            let lines = text.split(whereSeparator: \.isNewline).map { String($0) }
            var best: Candidate?

            for raw in lines {
                let line = raw.trimmingCharacters(in: .whitespaces)
                let lower = line.lowercased()

                // skip noise lines
                if negative.contains(where: { lower.contains($0) }) { continue }

                // find all number+currency matches in the line
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let ns = line as NSString
                let range = NSRange(location: 0, length: ns.length)

                regex.enumerateMatches(in: line, range: range) { match, _, _ in
                    guard let match = match else { return }
                    let numStr = ns.substring(with: match.range(withName: "NUM"))
                    guard let amount = normalizeNumber(numStr) else { return }

                    // currency before/after
                    var cur: String?
                    if match.range(withName: "CUR").location != NSNotFound {
                        cur = ns.substring(with: match.range(withName: "CUR"))
                    } else if match.range(withName: "CUR2").location != NSNotFound {
                        cur = ns.substring(with: match.range(withName: "CUR2"))
                    }
                    cur = cur?.lowercased().replacingOccurrences(of: " ", with: "")
                    let mapped = cur.flatMap { currencyMap[$0] }

                    // scoring
                    var score = 1
                    if positive.contains(where: { lower.contains($0) }) { score += 3 }
                    if mapped != nil { score += 2 } // prefer explicit currency
                    if lower.contains("subtotal") { score -= 1 } // de-prime subtotals
                    if lower.contains("unit") || lower.contains("qty") { score -= 1 } // avoid line items

                    let cand = Candidate(amount: amount, currency: mapped, score: score)

                    if let b = best {
                        if cand.score > b.score || (cand.score == b.score && cand.amount > b.amount) {
                            best = cand
                        }
                    } else {
                        best = cand
                    }
                }
            }

            // If nothing matched on scored lines, fallback: search all numbers and pick the largest with any currency
            if best == nil {
                var fallback: Candidate?
                let joined = lines.joined(separator: "\n")
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let ns = joined as NSString
                    let range = NSRange(location: 0, length: ns.length)
                    regex.enumerateMatches(in: joined, range: range) { match, _, _ in
                        guard let match = match else { return }
                        let numStr = ns.substring(with: match.range(withName: "NUM"))
                        if let amount = normalizeNumber(numStr) {
                            var cur: String?
                            if match.range(withName: "CUR").location != NSNotFound {
                                cur = ns.substring(with: match.range(withName: "CUR"))
                            } else if match.range(withName: "CUR2").location != NSNotFound {
                                cur = ns.substring(with: match.range(withName: "CUR2"))
                            }
                            cur = cur?.lowercased().replacingOccurrences(of: " ", with: "")
                            let mapped = cur.flatMap { currencyMap[$0] }
                            let cand = Candidate(amount: amount, currency: mapped, score: mapped == nil ? 0 : 1)
                            if let f = fallback {
                                if cand.amount > f.amount { fallback = cand }
                            } else {
                                fallback = cand
                            }
                        }
                    }
                }
                best = fallback
            }

            return (best?.amount, best?.currency)
        }

        private func recognizeText(from images: [UIImage]) -> String {
            var combined = ""
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            for img in images {
                guard let cg = img.cgImage else { continue }
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([request])
                    let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                    combined.append(lines.joined(separator: "\n"))
                    combined.append("\n")
                } catch {
                    print("Text recognition failed: \(error.localizedDescription)")
                }
            }
            return combined
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

private extension String {
    func pad2() -> String { count == 1 ? "0" + self : self }
}
