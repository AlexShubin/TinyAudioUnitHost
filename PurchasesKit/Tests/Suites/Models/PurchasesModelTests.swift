//
//  PurchasesModelTests.swift
//  PurchasesKitTests
//
//  Created by Alex Shubin on 07.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Testing
import PurchasesKitTestSupport
@testable import PurchasesKit

@Suite @MainActor
struct PurchasesModelTests {
    var gatewaySpy: StoreKitGatewaySpy!
    var sut: PurchasesModelType!

    init() {
        gatewaySpy = StoreKitGatewaySpy()
    }

    mutating func createSut() {
        sut = PurchasesModel(gateway: gatewaySpy)
    }

    // MARK: - init

    @Test
    mutating func initObservesTransactionUpdates() {
        createSut()
        #expect(gatewaySpy.calls == [.observeTransactionUpdates])
    }

    @Test
    mutating func initialStateIsLoadingWithoutProductInfo() {
        createSut()
        #expect(sut.state == .loading)
        #expect(sut.productInfo == nil)
    }

    // MARK: - load

    @Test
    mutating func loadMapsProductDisplayFields() async {
        gatewaySpy.productsResult = .success([
            StoreProductSpy(displayName: "TAU Pro", description: "Unlock everything", displayPrice: "$9.99")
        ])
        createSut()
        await sut.load()
        #expect(sut.productInfo == .fake(displayName: "TAU Pro", description: "Unlock everything", displayPrice: "$9.99"))
    }

    @Test
    mutating func loadRequestsProProduct() async {
        createSut()
        await sut.load()
        #expect(gatewaySpy.calls.contains(.products([PurchasesModel.proProductID])))
    }

    @Test
    mutating func loadLeavesProductInfoNilWhenNoProduct() async {
        gatewaySpy.productsResult = .success([])
        createSut()
        await sut.load()
        #expect(sut.productInfo == nil)
    }

    @Test
    mutating func loadLeavesProductInfoNilWhenFetchFails() async {
        gatewaySpy.productsResult = .failure(StoreKitGatewayError(message: "offline"))
        createSut()
        await sut.load()
        #expect(sut.productInfo == nil)
    }

    @Test
    mutating func loadLandsOnProWithMatchingEntitlement() async {
        gatewaySpy.currentEntitlementsResult = [StoreTransactionSpy(productID: PurchasesModel.proProductID)]
        createSut()
        await sut.load()
        #expect(sut.state == .pro)
    }

    @Test
    mutating func loadLandsOnFreeWithoutMatchingEntitlement() async {
        gatewaySpy.currentEntitlementsResult = [StoreTransactionSpy(productID: "some.other.product")]
        createSut()
        await sut.load()
        #expect(sut.state == .free)
    }

    // MARK: - purchase

    @Test
    mutating func purchaseIsIgnoredWhileLoading() async {
        let product = StoreProductSpy()
        gatewaySpy.productsResult = .success([product])
        createSut()
        await sut.purchase()
        #expect(sut.state == .loading)
        #expect(product.calls.isEmpty)
    }

    @Test
    mutating func purchaseIsIgnoredWhenPro() async {
        let product = StoreProductSpy()
        gatewaySpy.productsResult = .success([product])
        gatewaySpy.currentEntitlementsResult = [StoreTransactionSpy(productID: PurchasesModel.proProductID)]
        createSut()
        await sut.load()
        await sut.purchase()
        #expect(sut.state == .pro)
        #expect(product.calls.isEmpty)
    }

    @Test
    mutating func purchaseFailsAsUnavailableWhenNoProduct() async {
        gatewaySpy.productsResult = .success([])
        createSut()
        await sut.load()
        await sut.purchase()
        #expect(sut.state == .failed(.productUnavailable))
    }

    @Test
    mutating func purchaseVerifiedFinishesTransactionAndLandsOnPro() async {
        let transaction = StoreTransactionSpy(productID: PurchasesModel.proProductID)
        gatewaySpy.productsResult = .success([StoreProductSpy(purchaseResult: .verified(transaction))])
        createSut()
        await sut.load()
        gatewaySpy.currentEntitlementsResult = [transaction]
        await sut.purchase()
        #expect(transaction.calls == [.finish])
        #expect(sut.state == .pro)
    }

    @Test
    mutating func purchaseUnverifiedFailsVerification() async {
        gatewaySpy.productsResult = .success([StoreProductSpy(purchaseResult: .unverified)])
        createSut()
        await sut.load()
        await sut.purchase()
        #expect(sut.state == .failed(.verificationFailed))
    }

    @Test
    mutating func purchaseUserCancelledReturnsToFree() async {
        gatewaySpy.productsResult = .success([StoreProductSpy(purchaseResult: .userCancelled)])
        createSut()
        await sut.load()
        await sut.purchase()
        #expect(sut.state == .free)
    }

    @Test
    mutating func purchasePendingReturnsToFree() async {
        gatewaySpy.productsResult = .success([StoreProductSpy(purchaseResult: .pending)])
        createSut()
        await sut.load()
        await sut.purchase()
        #expect(sut.state == .free)
    }

    @Test
    mutating func purchaseUnknownFailsWithGenericMessage() async {
        gatewaySpy.productsResult = .success([StoreProductSpy(purchaseResult: .unknown)])
        createSut()
        await sut.load()
        await sut.purchase()
        #expect(sut.state == .failed(.unknown("Unknown purchase result")))
    }

    @Test
    mutating func purchaseFailedCarriesMessage() async {
        gatewaySpy.productsResult = .success([StoreProductSpy(purchaseResult: .failed("boom"))])
        createSut()
        await sut.load()
        await sut.purchase()
        #expect(sut.state == .failed(.unknown("boom")))
    }

    @Test
    mutating func purchaseCanRetryAfterFailure() async {
        let product = StoreProductSpy(purchaseResult: .failed("boom"))
        gatewaySpy.productsResult = .success([product])
        createSut()
        await sut.load()
        await sut.purchase()
        product.purchaseResult = .userCancelled
        await sut.purchase()
        #expect(product.calls == [.purchase, .purchase])
        #expect(sut.state == .free)
    }

    // MARK: - restore

    @Test
    mutating func restoreIsIgnoredWhileLoading() async {
        createSut()
        await sut.restore()
        #expect(sut.state == .loading)
        #expect(!gatewaySpy.calls.contains(.syncWithAppStore))
    }

    @Test
    mutating func restoreSyncsAndLandsOnPro() async {
        createSut()
        await sut.load()
        gatewaySpy.currentEntitlementsResult = [StoreTransactionSpy(productID: PurchasesModel.proProductID)]
        await sut.restore()
        #expect(sut.state == .pro)
        #expect(gatewaySpy.calls.contains(.syncWithAppStore))
    }

    @Test
    mutating func restoreWithoutEntitlementReturnsToFree() async {
        createSut()
        await sut.load()
        await sut.restore()
        #expect(sut.state == .free)
    }

    @Test
    mutating func restoreFailsWhenSyncFails() async {
        gatewaySpy.syncWithAppStoreError = StoreKitGatewayError(message: "no network")
        createSut()
        await sut.load()
        await sut.restore()
        #expect(sut.state == .failed(.unknown("no network")))
    }

    // MARK: - transaction updates

    @Test
    mutating func transactionUpdateFinishesTransactionAndUpdatesState() async {
        createSut()
        await sut.load()
        let transaction = StoreTransactionSpy(productID: PurchasesModel.proProductID)
        gatewaySpy.currentEntitlementsResult = [transaction]
        await gatewaySpy.transactionUpdatesHandler?(transaction)
        #expect(transaction.calls == [.finish])
        #expect(sut.state == .pro)
    }

    @Test
    mutating func transactionUpdateWhileLoadingStillUpdatesState() async {
        createSut()
        let transaction = StoreTransactionSpy(productID: PurchasesModel.proProductID)
        gatewaySpy.currentEntitlementsResult = [transaction]
        await gatewaySpy.transactionUpdatesHandler?(transaction)
        #expect(transaction.calls == [.finish])
        #expect(sut.state == .pro)
    }
}
