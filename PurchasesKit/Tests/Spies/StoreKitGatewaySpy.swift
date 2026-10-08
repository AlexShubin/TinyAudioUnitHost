//
//  StoreKitGatewaySpy.swift
//  PurchasesKitTests
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
@testable import PurchasesKit

final class StoreKitGatewaySpy: StoreKitGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
        case products([String])
        case syncWithAppStore
        case currentEntitlements
        case observeTransactionUpdates
    }

    private(set) var calls: [Calls] = []

    var productsResult: Result<[any StoreProductType], StoreKitGatewayError> = .success([])
    func products(for ids: [String]) async throws(StoreKitGatewayError) -> [any StoreProductType] {
        calls.append(.products(ids))
        return try productsResult.get()
    }

    var syncWithAppStoreError: StoreKitGatewayError?
    func syncWithAppStore() async throws(StoreKitGatewayError) {
        calls.append(.syncWithAppStore)
        if let syncWithAppStoreError { throw syncWithAppStoreError }
    }

    var currentEntitlementsResult: [any StoreTransactionType] = []
    func currentEntitlements() async -> [any StoreTransactionType] {
        calls.append(.currentEntitlements)
        return currentEntitlementsResult
    }

    private(set) var transactionUpdatesHandler: (@Sendable (any StoreTransactionType) async -> Void)?
    func observeTransactionUpdates(
        _ handler: @escaping @Sendable (any StoreTransactionType) async -> Void
    ) -> Cancellation {
        transactionUpdatesHandler = handler
        calls.append(.observeTransactionUpdates)
        return Cancellation {}
    }
}
