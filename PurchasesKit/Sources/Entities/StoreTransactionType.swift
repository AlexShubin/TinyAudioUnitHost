//
//  StoreTransactionType.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StoreKit

protocol StoreTransactionType: Sendable {
    var productID: String { get }
    func finish() async
}

extension Transaction: StoreTransactionType {}
