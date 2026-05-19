//
//  PurchasesService.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import StoreKit

public protocol PurchasesServiceType: Sendable {
    var isPro: Bool { get async }
    var productInfo: ProProductInfo? { get async }
    func purchase() async -> PurchaseResult
    func restore() async -> PurchaseResult
}

final actor PurchasesService: PurchasesServiceType {
    static let proProductID = "com.alexshubin.TinyAudioUnitHost.pro"

    private var cachedProduct: Product?
    private var updatesTask: Task<Void, Never>?

    init() {
        Task { await self.startListeningForUpdates() }
    }

    var isPro: Bool {
        get async {
            await checkEntitlements()
        }
    }

    var productInfo: ProProductInfo? {
        get async {
            guard let product = await fetchProduct() else { return nil }
            return ProProductInfo(
                displayName: product.displayName,
                description: product.description,
                displayPrice: product.displayPrice
            )
        }
    }

    func purchase() async -> PurchaseResult {
        guard let product = await fetchProduct() else { return .productUnavailable }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .verificationFailed
                }
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .unknownError("Unknown purchase result")
            }
        } catch {
            return .unknownError(error.localizedDescription)
        }
    }

    func restore() async -> PurchaseResult {
        do {
            try await AppStore.sync()
            return .success
        } catch {
            return .unknownError(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func fetchProduct() async -> Product? {
        if let cachedProduct { return cachedProduct }
        do {
            let products = try await Product.products(for: [Self.proProductID])
            cachedProduct = products.first
            return cachedProduct
        } catch {
            return nil
        }
    }

    private func checkEntitlements() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID {
                return true
            }
        }
        return false
    }

    /// Consume Transaction.updates so out-of-band transactions (promo purchases,
    /// ask-to-buy approvals, etc.) get acknowledged. We don't broadcast — callers
    /// read `isPro` on demand.
    private func startListeningForUpdates() {
        updatesTask = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }
}
