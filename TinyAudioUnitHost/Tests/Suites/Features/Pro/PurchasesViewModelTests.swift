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

    // MARK: - task

    @Test
    mutating func task_readsIsProFromService() async {
        serviceMock = PurchasesServiceMock(isPro: true)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.isPro == true)
    }

    @Test
    mutating func task_readsPriceLabelFromProductInfo() async {
        let info = ProProductInfo(displayName: "Pro", description: "Desc", displayPrice: "$9.99")
        serviceMock = PurchasesServiceMock(productInfo: info)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.priceLabel == "$9.99")
    }

    @Test
    mutating func task_nothingFromService_priceLabelStaysNil() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.isPro == false)
        #expect(sut.priceLabel == nil)
    }

    // MARK: - buyTapped

    @Test
    mutating func buyTapped_success_setsIsProAndClearsErrorMessage() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .success)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.isPro == true)
        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func buyTapped_userCancelled_keepsIsProFalseAndNoError() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .userCancelled)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.isPro == false)
        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func buyTapped_productUnavailable_setsErrorMessage() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .productUnavailable)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.errorMessage == "This product isn't available right now.")
    }

    @Test
    mutating func buyTapped_verificationFailed_setsErrorMessage() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .verificationFailed)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.errorMessage == "Purchase couldn't be verified.")
    }

    @Test
    mutating func buyTapped_unknownError_setsErrorMessageWithText() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .unknownError("oops"))
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.errorMessage == "oops")
    }

    @Test
    mutating func buyTapped_endsInIdle() async {
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.isPurchasing == false)
        #expect(sut.isUpgradeButtonDisabled == false)
        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - restoreTapped

    @Test
    mutating func restoreTapped_success_picksUpExistingEntitlement() async {
        serviceMock = PurchasesServiceMock(isPro: true, restoreResult: .success)
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.isPro == true)
        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func restoreTapped_productUnavailable_setsErrorMessage() async {
        serviceMock = PurchasesServiceMock(restoreResult: .productUnavailable)
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.errorMessage == "This product isn't available right now.")
    }

    @Test
    mutating func restoreTapped_endsInIdle() async {
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.isPurchasing == false)
        #expect(sut.isRestoreButtonDisabled == false)
    }
}
