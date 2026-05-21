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
    var productInfo: ProProductInfo? { get async }
    func makeIsProStream() async -> AsyncStream<Bool>
    func purchase() async -> PurchaseResult
    func restore() async -> PurchaseResult
}

final actor PurchasesService: PurchasesServiceType {
    static let proProductID = "com.alexshubin.TinyAudioUnitHost.pro"

    private var cachedProduct: Product?
    private var updatesTask: Task<Void, Never>?
    private var currentIsPro: Bool?
    private var subscribers: [UUID: AsyncStream<Bool>.Continuation] = [:]

    init() {
        Task {
            await self.startListeningForUpdates()
            await self.refreshIsPro()
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

    func makeIsProStream() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let id = UUID()
        subscribers[id] = continuation
        if let currentIsPro {
            continuation.yield(currentIsPro)
        }
        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.removeSubscriber(id: id)
            }
        }
        return stream
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
                    await refreshIsPro()
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
            await refreshIsPro()
            return .success
        } catch {
            return .unknownError(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func removeSubscriber(id: UUID) {
        subscribers.removeValue(forKey: id)
    }

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

    private func refreshIsPro() async {
        let next = await checkEntitlements()
        guard next != currentIsPro else { return }
        currentIsPro = next
        for continuation in subscribers.values {
            continuation.yield(next)
        }
    }

    /// Consume Transaction.updates so out-of-band transactions (promo purchases,
    /// ask-to-buy approvals, etc.) get acknowledged, and refresh pro status so
    /// subscribers see the new entitlement.
    private func startListeningForUpdates() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshIsPro()
                }
            }
        }
    }
}
