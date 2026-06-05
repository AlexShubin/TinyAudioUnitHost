//
//  ProProductInfo+Fake.swift
//  PurchasesKitTestSupport
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PurchasesKit

public extension ProProductInfo {
    static func fake(
        displayName: String = "Pro",
        description: String = "Pro features",
        displayPrice: String = "$4.99"
    ) -> ProProductInfo {
        ProProductInfo(displayName: displayName, description: description, displayPrice: displayPrice)
    }
}
