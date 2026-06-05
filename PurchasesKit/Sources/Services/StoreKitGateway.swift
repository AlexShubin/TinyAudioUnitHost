//
//  StoreKitGateway.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StoreKit

protocol StoreKitGatewayType: Sendable {
    func products(for ids: [String]) async throws(StoreKitGatewayError) -> [any StoreProductType]
    func syncWithAppStore() async throws(StoreKitGatewayError)
    func currentEntitlements() -> AsyncStream<StoreVerification>
    func transactionUpdates() -> AsyncStream<StoreVerification>
}

enum StoreVerification {
    case verified(any StoreTransactionType)
    case unverified
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

    func currentEntitlements() -> AsyncStream<StoreVerification> {
        stream(from: Transaction.currentEntitlements)
    }

    func transactionUpdates() -> AsyncStream<StoreVerification> {
        stream(from: Transaction.updates)
    }

    private func stream(from sequence: Transaction.Transactions) -> AsyncStream<StoreVerification> {
        AsyncStream { continuation in
            let task = Task {
                for await result in sequence {
                    continuation.yield(StoreVerification(from: result))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension StoreVerification {
    init(from result: VerificationResult<Transaction>) {
        switch result {
        case .verified(let transaction): self = .verified(transaction)
        case .unverified: self = .unverified
        }
    }
}
