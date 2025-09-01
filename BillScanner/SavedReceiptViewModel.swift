//
//  SavedReceiptViewModel.swift
//  BillScanner
//
//  Created by David Walitza on 21.05.2025.
//

import Foundation
import Combine

final class SavedReceiptsViewModel: ObservableObject {
    /// Published array of receipts for the view to observe.
    @Published private(set) var receipts: [Receipt]

    /// Underlying persistence store (singleton).
    private let store: ReceiptStore

    /// Default initializer: loads from the shared store.
    init(store: ReceiptStore = .shared) {
        self.store = store
        self.receipts = []
        loadReceipts()
    }

    /// Preview initializer: inject receipts for SwiftUI previews.
    init(previewReceipts: [Receipt]) {
        self.store = .shared
        self.receipts = previewReceipts
    }

    /// Loads all receipts from the store.
    func loadReceipts() {
        receipts = store.getAll()
    }

    /// Adds a new receipt and refreshes the list.
    func addReceipt(_ receipt: Receipt) {
        store.add(receipt)
        loadReceipts()
    }

    /// Updates an existing receipt and refreshes the list.
    func updateReceipt(_ receipt: Receipt) {
        store.update(receipt)
        loadReceipts()
    }

    /// Deletes a receipt and refreshes the list.
    func deleteReceipt(_ receipt: Receipt) {
        store.delete(receipt)
        loadReceipts()
    }
}
