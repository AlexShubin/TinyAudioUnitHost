//
//  PurchasesModelSpy.swift
//  PurchasesKitTestSupport
//
//  Created by Alex Shubin on 07.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
import PurchasesKit

@MainActor @Observable
public final class PurchasesModelSpy: PurchasesModelType {
    public enum Calls: Equatable, Sendable {
        case load
        case purchase
        case restore
    }

    public private(set) var calls: [Calls] = []

    public var state: PurchasesState = .loading
    public var productInfo: ProProductInfo?

    public init() {}

    public func load() async {
        calls.append(.load)
    }

    public func purchase() async {
        calls.append(.purchase)
    }

    public func restore() async {
        calls.append(.restore)
    }
}
