//
//  StoreProductType.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StoreKit

protocol StoreProductType: Sendable {
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    var displayPrice: String { get }
    func purchase() async -> StorePurchaseOutcome
}

enum StorePurchaseOutcome {
    case verified(any StoreTransactionType)
    case unverified
    case userCancelled
    case pending
    case unknown
    case failed(String)
}

extension Product: StoreProductType {
    func purchase() async -> StorePurchaseOutcome {
        do {
            return StorePurchaseOutcome(from: try await purchase(options: []))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

private extension StorePurchaseOutcome {
    init(from result: Product.PurchaseResult) {
        switch result {
        case .success(.verified(let transaction)): self = .verified(transaction)
        case .success(.unverified): self = .unverified
        case .userCancelled: self = .userCancelled
        case .pending: self = .pending
        @unknown default: self = .unknown
        }
    }
}
