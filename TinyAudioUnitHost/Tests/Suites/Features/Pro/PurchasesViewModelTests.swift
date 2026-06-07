//
//  PurchasesViewModelTests.swift
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
struct PurchasesViewModelTests {
    var serviceMock: PurchasesServiceMock!
    var sut: PurchasesViewModelType!

    init() {
        serviceMock = PurchasesServiceMock()
    }

    mutating func createSut() {
        sut = PurchasesViewModel(purchasesService: serviceMock)
    }

    // MARK: - isPro stream

    @Test
    mutating func init_subscribesToIsProStream() async {
        serviceMock.isProStream.continuation.yield(true)
        createSut()

        await next { sut.isPro }
        #expect(sut.isPro == true)
    }

    @Test
    mutating func isPro_updatesWhenServiceBroadcastsChange() async {
        createSut()

        #expect(sut.isPro == false)

        serviceMock.isProStream.continuation.yield(true)

        await next { sut.isPro }
        #expect(sut.isPro == true)
    }

    // MARK: - task

    @Test
    mutating func task_readsPriceLabelFromProductInfo() async {
        serviceMock.productInfoResult = ProProductInfo(displayName: "Pro", description: "Desc", displayPrice: "$9.99")
        createSut()

        await sut.accept(action: .task)

        #expect(sut.priceLabel == "$9.99")
    }

    @Test
    mutating func task_noProductInfo_priceLabelStaysNil() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.priceLabel == nil)
    }

    // MARK: - buyTapped

    @Test
    mutating func buyTapped_success_clearsErrorMessage() async {
        serviceMock.purchaseResult = .success
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func buyTapped_userCancelled_keepsIsProFalseAndNoError() async {
        serviceMock.purchaseResult = .userCancelled
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.isPro == false)
        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func buyTapped_productUnavailable_setsErrorMessage() async {
        serviceMock.purchaseResult = .productUnavailable
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.errorMessage == "This product isn't available right now.")
    }

    @Test
    mutating func buyTapped_verificationFailed_setsErrorMessage() async {
        serviceMock.purchaseResult = .verificationFailed
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.errorMessage == "Purchase couldn't be verified.")
    }

    @Test
    mutating func buyTapped_unknownError_setsErrorMessageWithText() async {
        serviceMock.purchaseResult = .unknownError("oops")
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.errorMessage == "oops")
    }

    @Test
    mutating func buyTapped_endsInIdle() async {
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.purchaseButtonState == .enabled)
        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - restoreTapped

    @Test
    mutating func restoreTapped_success_clearsErrorMessage() async {
        serviceMock.restoreResult = .success
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func restoreTapped_productUnavailable_setsErrorMessage() async {
        serviceMock.restoreResult = .productUnavailable
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.errorMessage == "This product isn't available right now.")
    }

    @Test
    mutating func restoreTapped_endsInIdle() async {
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.purchaseButtonState == .enabled)
        #expect(sut.isRestoreButtonDisabled == false)
    }
}
