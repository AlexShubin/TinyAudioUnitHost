//
//  Dependencies.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct Dependencies: Sendable {
    public let purchasesService: PurchasesServiceType

    public static let live = Dependencies(
        purchasesService: PurchasesService(gateway: StoreKitGateway())
    )
}
