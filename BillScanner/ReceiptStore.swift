//
//  ReceiptStore.swift
//  BillScanner
//
//  Created by David Walitza on 14.06.2025.
//
import Foundation

final class ReceiptStore {
    // MARK: - Singleton access (optional)
    static let shared = ReceiptStore()

    // MARK: - Public interface
    /// All loaded receipts, in memory.
    private(set) var receipts: [Receipt] = []

    /// Returns a copy of current receipts.
    func getAll() -> [Receipt] {
        return receipts
    }

    /// Adds a new receipt and persists immediately.
    func add(_ receipt: Receipt) {
        receipts.append(receipt)
        save()
    }

    /// Updates an existing receipt (matched by `id`) and persists.
    func update(_ updated: Receipt) {
        guard let idx = receipts.firstIndex(where: { $0.id == updated.id }) else { return }
        receipts[idx] = updated
        save()
    }

    /// Deletes a receipt (matched by `id`) and persists.
    func delete(_ receipt: Receipt) {
        receipts.removeAll { $0.id == receipt.id }
        save()
    }

    // MARK: - Initialization & Persistence
    private init() {
        load()
    }

    /// URL of the JSON file in the app’s Documents directory.
    private var storeURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("receipts.json")
    }

    /// Load from disk into `receipts`.
    private func load() {
        do {
            let data = try Data(contentsOf: storeURL)
            let decoded = try JSONDecoder().decode([Receipt].self, from: data)
            receipts = decoded
        } catch {
            // If file missing or decode fails, start fresh
            receipts = []
            print("ReceiptStore load error:", error)
        }
    }

    /// Encode `receipts` and write to disk.
    private func save() {
        do {
            let data = try JSONEncoder().encode(receipts)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("ReceiptStore save error:", error)
        }
    }
}
