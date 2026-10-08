//
//  PurchasesPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import PurchasesKit
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PurchasesPresenterTests {
    var purchasesSpy: PurchasesModelSpy!
    var sut: PurchasesPresenter!

    init() {
        purchasesSpy = PurchasesModelSpy()
    }

    mutating func createSut() {
        sut = PurchasesPresenter(purchases: purchasesSpy)
    }

    // MARK: - isPro

    @Test
    mutating func isPro_trueOnlyInProState() {
        createSut()

        purchasesSpy.state = .pro
        #expect(sut.isPro == true)

        purchasesSpy.state = .free
        #expect(sut.isPro == false)
    }

    // MARK: - isBusy

    @Test
    mutating func isBusy_trueOnlyWhileLoading() {
        createSut()

        purchasesSpy.state = .loading
        #expect(sut.isBusy == true)

        purchasesSpy.state = .free
        #expect(sut.isBusy == false)

        purchasesSpy.state = .failed(.unknown("oops"))
        #expect(sut.isBusy == false)

        purchasesSpy.state = .pro
        #expect(sut.isBusy == false)
    }

    // MARK: - priceLabel

    @Test
    mutating func priceLabel_readsDisplayPrice() {
        purchasesSpy.productInfo = .fake(displayPrice: "$9.99")
        createSut()

        #expect(sut.priceLabel == "$9.99")
    }

    @Test
    mutating func priceLabel_nilWithoutProductInfo() {
        createSut()

        #expect(sut.priceLabel == nil)
    }

    // MARK: - errorMessage

    @Test
    mutating func errorMessage_nilUnlessFailed() {
        createSut()

        purchasesSpy.state = .loading
        #expect(sut.errorMessage == nil)

        purchasesSpy.state = .free
        #expect(sut.errorMessage == nil)

        purchasesSpy.state = .pro
        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func errorMessage_productUnavailable() {
        purchasesSpy.state = .failed(.productUnavailable)
        createSut()

        #expect(sut.errorMessage == "This product isn't available right now.")
    }

    @Test
    mutating func errorMessage_verificationFailed() {
        purchasesSpy.state = .failed(.verificationFailed)
        createSut()

        #expect(sut.errorMessage == "Purchase couldn't be verified.")
    }

    @Test
    mutating func errorMessage_unknownCarriesText() {
        purchasesSpy.state = .failed(.unknown("oops"))
        createSut()

        #expect(sut.errorMessage == "oops")
    }

    // MARK: - actions

    @Test
    mutating func buy_forwardsPurchase() async {
        createSut()

        await sut.buy()

        #expect(purchasesSpy.calls == [.purchase])
    }

    @Test
    mutating func restore_forwardsRestore() async {
        createSut()

        await sut.restore()

        #expect(purchasesSpy.calls == [.restore])
    }
}
