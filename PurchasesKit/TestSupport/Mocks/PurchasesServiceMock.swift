//
//  PurchasesServiceMock.swift
//  PurchasesKitTestSupport
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import PurchasesKit

public final class PurchasesServiceMock: PurchasesServiceType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case productInfo
        case purchase
        case restore
        case start
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var productInfoResult: ProProductInfo?
    public var productInfo: ProProductInfo? {
        get async {
            calls.append(.productInfo)
            return productInfoResult
        }
    }

    public var isProStream = AsyncStream<Bool>.makeStream()
    public func makeIsProStream() async -> AsyncStream<Bool> {
        isProStream.stream
    }

    public var purchaseResult: PurchaseResult = .success
    public func purchase() async -> PurchaseResult {
        calls.append(.purchase)
        return purchaseResult
    }

    public var restoreResult: PurchaseResult = .success
    public func restore() async -> PurchaseResult {
        calls.append(.restore)
        return restoreResult
    }

    @discardableResult
    public func start() -> Task<Void, Error> {
        calls.append(.start)
        return Task {}
    }
}
