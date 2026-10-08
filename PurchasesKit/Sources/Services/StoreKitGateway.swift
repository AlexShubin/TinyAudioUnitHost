//
//  StoreKitGateway.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import StoreKit

protocol StoreKitGatewayType: Sendable {
    func products(for ids: [String]) async throws(StoreKitGatewayError) -> [any StoreProductType]
    func syncWithAppStore() async throws(StoreKitGatewayError)
    func currentEntitlements() async -> [any StoreTransactionType]
    func observeTransactionUpdates(
        _ handler: @escaping @Sendable (any StoreTransactionType) async -> Void
    ) -> Cancellation
}

struct StoreKitGatewayError: Error, Equatable {
    let message: String
}

struct StoreKitGateway: StoreKitGatewayType {
    func products(for ids: [String]) async throws(StoreKitGatewayError) -> [any StoreProductType] {
        do {
            return try await Product.products(for: ids)
        } catch {
            throw StoreKitGatewayError(message: error.localizedDescription)
        }
    }

    func syncWithAppStore() async throws(StoreKitGatewayError) {
        do {
            try await AppStore.sync()
        } catch {
            throw StoreKitGatewayError(message: error.localizedDescription)
        }
    }

    func currentEntitlements() async -> [any StoreTransactionType] {
        var transactions: [any StoreTransactionType] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                transactions.append(transaction)
            }
        }
        return transactions
    }

    func observeTransactionUpdates(
        _ handler: @escaping @Sendable (any StoreTransactionType) async -> Void
    ) -> Cancellation {
        let task = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await handler(transaction)
                }
            }
        }
        return Cancellation { task.cancel() }
    }
}
