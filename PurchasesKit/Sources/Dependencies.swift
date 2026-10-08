//
//  Dependencies.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@MainActor
public struct Dependencies: Sendable {
    public let purchasesModel: PurchasesModelType

    public static let live = Dependencies(
        purchasesModel: PurchasesModel(gateway: StoreKitGateway())
    )
}
