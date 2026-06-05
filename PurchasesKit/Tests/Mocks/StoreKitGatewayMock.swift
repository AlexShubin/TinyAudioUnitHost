//
//  StoreKitGatewayMock.swift
//  PurchasesKitTests
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import PurchasesKit

final class StoreKitGatewayMock: StoreKitGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
        case products([String])
        case syncWithAppStore
        case currentEntitlements
        case transactionUpdates
    }

    private(set) var calls: [Calls] = []
    var productsResult: [any StoreProductType]
    var productsError: StoreKitGatewayError?
    var syncError: StoreKitGatewayError?
    var entitlements: [StoreVerification]
    var updates: [StoreVerification]

    init(
        productsResult: [any StoreProductType] = [],
        productsError: StoreKitGatewayError? = nil,
        syncError: StoreKitGatewayError? = nil,
        entitlements: [StoreVerification] = [],
        updates: [StoreVerification] = []
    ) {
        self.productsResult = productsResult
        self.productsError = productsError
        self.syncError = syncError
        self.entitlements = entitlements
        self.updates = updates
    }

    func products(for ids: [String]) async throws(StoreKitGatewayError) -> [any StoreProductType] {
        calls.append(.products(ids))
        if let productsError { throw productsError }
        return productsResult
    }

    func syncWithAppStore() async throws(StoreKitGatewayError) {
        calls.append(.syncWithAppStore)
        if let syncError { throw syncError }
    }

    func currentEntitlements() -> AsyncStream<StoreVerification> {
        calls.append(.currentEntitlements)
        return Self.stream(yielding: entitlements)
    }

    func transactionUpdates() -> AsyncStream<StoreVerification> {
        calls.append(.transactionUpdates)
        return Self.stream(yielding: updates)
    }

    private static func stream(yielding values: [StoreVerification]) -> AsyncStream<StoreVerification> {
        AsyncStream { continuation in
            values.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}
