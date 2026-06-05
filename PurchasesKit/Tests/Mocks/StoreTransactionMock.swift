//
//  StoreTransactionMock.swift
//  PurchasesKitTests
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import PurchasesKit

final class StoreTransactionMock: StoreTransactionType, @unchecked Sendable {
    enum Calls: Equatable {
        case finish
    }

    private(set) var calls: [Calls] = []
    var productID: String

    init(productID: String = "pro") {
        self.productID = productID
    }

    func finish() async {
        calls.append(.finish)
    }
}
