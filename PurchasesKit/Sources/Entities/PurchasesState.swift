//
//  PurchasesState.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public enum PurchasesState: Sendable, Equatable {
    case loading
    case free
    case failed(PurchaseError)
    case pro
}

public enum PurchaseError: Sendable, Equatable {
    case productUnavailable
    case verificationFailed
    case unknown(String)
}

public extension PurchasesState {
    var isPro: Bool { self == .pro }
}
