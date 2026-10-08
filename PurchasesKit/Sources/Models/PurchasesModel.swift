//
//  PurchasesModel.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 07.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import Foundation
import Observation

@MainActor
public protocol PurchasesModelType: AnyObject, Observable, Sendable {
    var state: PurchasesState { get }
    var productInfo: ProProductInfo? { get }
    func load() async
    func purchase() async
    func restore() async
}

@MainActor @Observable
final class PurchasesModel: PurchasesModelType {
    static let proProductID = "com.alexshubin.TinyAudioUnitHost.pro"

    private(set) var state: PurchasesState = .loading
    private(set) var productInfo: ProProductInfo?

    @ObservationIgnored private let gateway: StoreKitGatewayType
    @ObservationIgnored private var cachedProduct: (any StoreProductType)?
    @ObservationIgnored private var updatesObservation: Cancellation?

    init(gateway: StoreKitGatewayType) {
        self.gateway = gateway
        updatesObservation = gateway.observeTransactionUpdates { [weak self] transaction in
            await transaction.finish()
            await self?.updateState()
        }
    }

    func load() async {
        _ = await fetchProduct()
        await updateState()
    }

    func purchase() async {
        guard state.isIdle else { return }
        state = .loading
        guard let product = await fetchProduct() else {
            state = .failed(.productUnavailable)
            return
        }
        switch await product.purchase() {
        case .verified(let transaction):
            await transaction.finish()
            await updateState()
        case .unverified:
            state = .failed(.verificationFailed)
        case .userCancelled, .pending:
            state = .free
        case .unknown:
            state = .failed(.unknown("Unknown purchase result"))
        case .failed(let message):
            state = .failed(.unknown(message))
        }
    }

    func restore() async {
        guard state.isIdle else { return }
        state = .loading
        do {
            try await gateway.syncWithAppStore()
            await updateState()
        } catch {
            state = .failed(.unknown(error.message))
        }
    }

    // MARK: - Private

    private func fetchProduct() async -> (any StoreProductType)? {
        if let cachedProduct { return cachedProduct }
        cachedProduct = try? await gateway.products(for: [Self.proProductID]).first
        productInfo = cachedProduct.map(ProProductInfo.init)
        return cachedProduct
    }

    private func updateState() async {
        let isPro = await gateway.currentEntitlements().contains { $0.productID == Self.proProductID }
        state = isPro ? .pro : .free
    }
}

private extension PurchasesState {
    var isIdle: Bool {
        switch self {
        case .free, .failed: true
        case .loading, .pro: false
        }
    }
}

private extension ProProductInfo {
    init(_ product: any StoreProductType) {
        self.init(
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice
        )
    }
}
