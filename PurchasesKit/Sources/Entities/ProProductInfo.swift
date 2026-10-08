//
//  ProProductInfo.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct ProProductInfo: Sendable, Equatable {
    public let displayName: String
    public let description: String
    public let displayPrice: String

    public init(displayName: String, description: String, displayPrice: String) {
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
    }
}
