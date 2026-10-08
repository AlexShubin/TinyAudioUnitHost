//
//  PurchasesPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import PurchasesKit

@MainActor
protocol PurchasesPresenterType {
    var isPro: Bool { get }
    var isBusy: Bool { get }
    var priceLabel: String? { get }
    var errorMessage: String? { get }
    func buy() async
    func restore() async
}

@MainActor
struct PurchasesPresenter: PurchasesPresenterType {
    var isPro: Bool { purchases.state.isPro }
    var isBusy: Bool { purchases.state == .loading }
    var priceLabel: String? { purchases.productInfo?.displayPrice }

    var errorMessage: String? {
        if case .failed(let error) = purchases.state {
            return error.message
        }
        return nil
    }

    private let purchases: PurchasesModelType

    init(purchases: PurchasesModelType) {
        self.purchases = purchases
    }

    func buy() async {
        await purchases.purchase()
    }

    func restore() async {
        await purchases.restore()
    }
}

private extension PurchaseError {
    var message: String {
        switch self {
        case .productUnavailable:
            "This product isn't available right now."
        case .verificationFailed:
            "Purchase couldn't be verified."
        case .unknown(let message):
            message
        }
    }
}
