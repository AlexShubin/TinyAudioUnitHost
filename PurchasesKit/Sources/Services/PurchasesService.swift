//
//  PurchasesService.swift
//  PurchasesKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public protocol PurchasesServiceType: Sendable {
    var productInfo: ProProductInfo? { get async }
    func makeIsProStream() async -> AsyncStream<Bool>
    func purchase() async -> PurchaseResult
    func restore() async -> PurchaseResult
    @discardableResult
    func startListening() -> Task<Void, Error>
}

final actor PurchasesService: PurchasesServiceType {
    static let proProductID = "com.alexshubin.TinyAudioUnitHost.pro"

    private let gateway: StoreKitGatewayType
    private var cachedProduct: (any StoreProductType)?
    private var currentIsPro: Bool?
    private var subscribers: [UUID: AsyncStream<Bool>.Continuation] = [:]

    init(gateway: StoreKitGatewayType) {
        self.gateway = gateway
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
        switch await product.purchase() {
        case .verified(let transaction):
            await transaction.finish()
            await refreshIsPro()
            return .success
        case .unverified:
            return .verificationFailed
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        case .unknown:
            return .unknownError("Unknown purchase result")
        case .failed(let message):
            return .unknownError(message)
        }
    }

    func restore() async -> PurchaseResult {
        do {
            try await gateway.syncWithAppStore()
            await refreshIsPro()
            return .success
        } catch {
            return .unknownError(error.message)
        }
    }

    @discardableResult
    nonisolated func startListening() -> Task<Void, Error> {
        let gateway = self.gateway
        return Task { [weak self] in
            await self?.refreshIsPro()
            for await result in gateway.transactionUpdates() {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshIsPro()
                }
            }
        }
    }

    // MARK: - Private

    private func removeSubscriber(id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    private func fetchProduct() async -> (any StoreProductType)? {
        if let cachedProduct { return cachedProduct }
        cachedProduct = try? await gateway.products(for: [Self.proProductID]).first
        return cachedProduct
    }

    private func checkEntitlements() async -> Bool {
        for await result in gateway.currentEntitlements() {
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
}
