//
//  PurchaseResult.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public enum PurchaseResult: Sendable, Equatable {
    case success
    case userCancelled
    case pending
    case productUnavailable
    case verificationFailed
    case unknownError(String)
}
