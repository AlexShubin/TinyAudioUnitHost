//
//  PurchasesServiceMock.swift
//  PurchasesKitTestSupport
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import PurchasesKit

public actor PurchasesServiceMock: PurchasesServiceType {
    public enum Calls: Equatable, Sendable {
        case productInfo
        case purchase
        case restore
    }

    public private(set) var calls: [Calls] = []
    public var currentIsPro: Bool
    public var currentProductInfo: ProProductInfo?
    public var purchaseResult: PurchaseResult
    public var restoreResult: PurchaseResult

    private var continuation: AsyncStream<Bool>.Continuation?

    public init(
        isPro: Bool = false,
        productInfo: ProProductInfo? = nil,
        purchaseResult: PurchaseResult = .success,
        restoreResult: PurchaseResult = .success
    ) {
        self.currentIsPro = isPro
        self.currentProductInfo = productInfo
        self.purchaseResult = purchaseResult
        self.restoreResult = restoreResult
    }

    public var productInfo: ProProductInfo? {
        get async {
            calls.append(.productInfo)
            return currentProductInfo
        }
    }

    public func makeIsProStream() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.continuation = continuation
        continuation.yield(currentIsPro)
        return stream
    }

    public func purchase() async -> PurchaseResult {
        calls.append(.purchase)
        if purchaseResult == .success {
            broadcastIsPro(true)
        }
        return purchaseResult
    }

    public func restore() async -> PurchaseResult {
        calls.append(.restore)
        return restoreResult
    }

    public func setIsPro(_ value: Bool) {
        broadcastIsPro(value)
    }

    public func setProductInfo(_ value: ProProductInfo?) {
        currentProductInfo = value
    }

    public func setPurchaseResult(_ value: PurchaseResult) {
        purchaseResult = value
    }

    public func setRestoreResult(_ value: PurchaseResult) {
        restoreResult = value
    }

    private func broadcastIsPro(_ value: Bool) {
        guard currentIsPro != value else { return }
        currentIsPro = value
        continuation?.yield(value)
    }
}
