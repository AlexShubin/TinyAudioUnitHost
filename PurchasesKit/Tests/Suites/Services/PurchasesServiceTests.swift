//
//  PurchasesServiceTests.swift
//  PurchasesKitTests
//
//  Created by Alex Shubin on 30.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Testing
import PurchasesKitTestSupport
@testable import PurchasesKit

@Suite
struct PurchasesServiceTests {
    var gatewayMock: StoreKitGatewayMock!
    var sut: PurchasesServiceType!

    init() {
        gatewayMock = StoreKitGatewayMock()
    }

    mutating func createSut() {
        sut = PurchasesService(gateway: gatewayMock)
    }

    // MARK: - productInfo

    @Test
    mutating func productInfoMapsProductDisplayFields() async {
        gatewayMock.productsResult = [
            StoreProductMock(displayName: "TAU Pro", description: "Unlock everything", displayPrice: "$9.99")
        ]
        createSut()
        #expect(await sut.productInfo == .fake(displayName: "TAU Pro", description: "Unlock everything", displayPrice: "$9.99"))
    }

    @Test
    mutating func productInfoNilWhenNoProduct() async {
        gatewayMock.productsResult = []
        createSut()
        #expect(await sut.productInfo == nil)
    }

    @Test
    mutating func productInfoNilWhenFetchFails() async {
        gatewayMock.productsError = StoreKitGatewayError(message: "offline")
        createSut()
        #expect(await sut.productInfo == nil)
    }

    // MARK: - purchase

    @Test
    mutating func purchaseReturnsUnavailableWhenNoProduct() async {
        gatewayMock.productsResult = []
        createSut()
        #expect(await sut.purchase() == .productUnavailable)
    }

    @Test
    mutating func purchaseVerifiedFinishesTransactionAndSucceeds() async {
        let transaction = StoreTransactionMock(productID: PurchasesService.proProductID)
        gatewayMock.productsResult = [StoreProductMock(purchaseResult: .verified(transaction))]
        createSut()
        let result = await sut.purchase()
        #expect(result == .success)
        #expect(transaction.calls == [.finish])
    }

    @Test
    mutating func purchaseUnverifiedReturnsVerificationFailed() async {
        gatewayMock.productsResult = [StoreProductMock(purchaseResult: .unverified)]
        createSut()
        #expect(await sut.purchase() == .verificationFailed)
    }

    @Test
    mutating func purchaseUserCancelledIsReported() async {
        gatewayMock.productsResult = [StoreProductMock(purchaseResult: .userCancelled)]
        createSut()
        #expect(await sut.purchase() == .userCancelled)
    }

    @Test
    mutating func purchasePendingIsReported() async {
        gatewayMock.productsResult = [StoreProductMock(purchaseResult: .pending)]
        createSut()
        #expect(await sut.purchase() == .pending)
    }

    @Test
    mutating func purchaseUnknownMapsToUnknownError() async {
        gatewayMock.productsResult = [StoreProductMock(purchaseResult: .unknown)]
        createSut()
        #expect(await sut.purchase() == .unknownError("Unknown purchase result"))
    }

    @Test
    mutating func purchaseFailedMapsToUnknownErrorWithMessage() async {
        gatewayMock.productsResult = [StoreProductMock(purchaseResult: .failed("boom"))]
        createSut()
        #expect(await sut.purchase() == .unknownError("boom"))
    }

    // MARK: - restore

    @Test
    mutating func restoreSucceedsWhenSyncSucceeds() async {
        createSut()
        #expect(await sut.restore() == .success)
    }

    @Test
    mutating func restoreReturnsUnknownErrorWhenSyncFails() async {
        gatewayMock.syncError = StoreKitGatewayError(message: "no network")
        createSut()
        #expect(await sut.restore() == .unknownError("no network"))
    }

    // MARK: - isPro stream

    @Test
    mutating func isProStreamEmitsTrueAfterVerifiedPurchase() async {
        gatewayMock.productsResult = [
            StoreProductMock(purchaseResult: .verified(StoreTransactionMock(productID: PurchasesService.proProductID)))
        ]
        gatewayMock.entitlements = [.verified(StoreTransactionMock(productID: PurchasesService.proProductID))]
        createSut()
        _ = await sut.purchase()
        var iterator = await sut.makeIsProStream().makeAsyncIterator()
        #expect(await iterator.next() == true)
    }

    @Test
    mutating func isProStreamEmitsFalseWithoutMatchingEntitlement() async {
        gatewayMock.entitlements = [.verified(StoreTransactionMock(productID: "some.other.product"))]
        createSut()
        _ = await sut.restore()
        var iterator = await sut.makeIsProStream().makeAsyncIterator()
        #expect(await iterator.next() == false)
    }

    // MARK: - startListening

    @Test
    mutating func startListeningRefreshesInitialProStatus() async {
        gatewayMock.entitlements = [.verified(StoreTransactionMock(productID: PurchasesService.proProductID))]
        createSut()
        try? await sut.startListening().value
        var iterator = await sut.makeIsProStream().makeAsyncIterator()
        #expect(await iterator.next() == true)
    }

    @Test
    mutating func startListeningFinishesVerifiedTransactionUpdates() async {
        let transaction = StoreTransactionMock(productID: PurchasesService.proProductID)
        gatewayMock.updates = [.verified(transaction)]
        createSut()
        try? await sut.startListening().value
        #expect(transaction.calls == [.finish])
    }
}
