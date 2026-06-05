//
//  StoreProductMock.swift
//  PurchasesKitTests
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import PurchasesKit

final class StoreProductMock: StoreProductType, @unchecked Sendable {
    enum Calls: Equatable {
        case purchase
    }

    private(set) var calls: [Calls] = []
    var id: String
    var displayName: String
    var description: String
    var displayPrice: String
    var purchaseResult: StorePurchaseOutcome

    init(
        id: String = "pro",
        displayName: String = "Pro",
        description: String = "Pro features",
        displayPrice: String = "$4.99",
        purchaseResult: StorePurchaseOutcome = .userCancelled
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.purchaseResult = purchaseResult
    }

    func purchase() async -> StorePurchaseOutcome {
        calls.append(.purchase)
        return purchaseResult
    }
}
