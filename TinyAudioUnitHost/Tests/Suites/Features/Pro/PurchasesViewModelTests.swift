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
    mutating func task_readsIsProAndProductInfoFromService() async {
        let info = ProProductInfo(displayName: "Pro", description: "Desc", displayPrice: "$9.99")
        serviceMock = PurchasesServiceMock(isPro: true, productInfo: info)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.state.isPro == true)
        #expect(sut.state.productInfo == info)
    }

    @Test
    mutating func task_serviceHasNothing_stateStaysFalseAndNil() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.state.isPro == false)
        #expect(sut.state.productInfo == nil)
    }

    @Test
    mutating func task_callsIsProAndProductInfoInOrder() async {
        createSut()

        await sut.accept(action: .task)

        #expect(await serviceMock.calls == [.isPro, .productInfo])
    }

    // MARK: - buyTapped

    @Test
    mutating func buyTapped_success_setsIsProTrueAndClearsError() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .success)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.state.isPro == true)
        #expect(sut.state.errorMessage == nil)
    }

    @Test
    mutating func buyTapped_userCancelled_keepsIsProFalseAndNoError() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .userCancelled)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.state.isPro == false)
        #expect(sut.state.errorMessage == nil)
    }

    @Test
    mutating func buyTapped_pending_noError() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .pending)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.state.errorMessage == nil)
    }

    @Test
    mutating func buyTapped_productUnavailable_setsErrorMessage() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .productUnavailable)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.state.errorMessage == "This product isn't available right now.")
    }

    @Test
    mutating func buyTapped_verificationFailed_setsErrorMessage() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .verificationFailed)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.state.errorMessage == "Purchase couldn't be verified.")
    }

    @Test
    mutating func buyTapped_unknownError_setsErrorMessageFromResult() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .unknownError("oops"))
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.state.errorMessage == "oops")
    }

    @Test
    mutating func buyTapped_endsWithIdlePhase() async {
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(sut.state.phase == .idle)
    }

    @Test
    mutating func buyTapped_callsPurchaseThenIsPro() async {
        serviceMock = PurchasesServiceMock(purchaseResult: .success)
        createSut()

        await sut.accept(action: .buyTapped)

        #expect(await serviceMock.calls == [.purchase, .isPro])
    }

    // MARK: - restoreTapped

    @Test
    mutating func restoreTapped_success_clearsError() async {
        serviceMock = PurchasesServiceMock(restoreResult: .success)
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.state.errorMessage == nil)
    }

    @Test
    mutating func restoreTapped_revealsExistingPurchase_updatesIsPro() async {
        serviceMock = PurchasesServiceMock(isPro: true, restoreResult: .success)
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.state.isPro == true)
    }

    @Test
    mutating func restoreTapped_noEntitlement_keepsIsProFalse() async {
        serviceMock = PurchasesServiceMock(restoreResult: .success)
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.state.isPro == false)
    }

    @Test
    mutating func restoreTapped_unknownError_setsErrorMessage() async {
        serviceMock = PurchasesServiceMock(restoreResult: .unknownError("network down"))
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.state.errorMessage == "network down")
    }

    @Test
    mutating func restoreTapped_endsWithIdlePhase() async {
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(sut.state.phase == .idle)
    }

    @Test
    mutating func restoreTapped_callsRestoreThenIsPro() async {
        serviceMock = PurchasesServiceMock(restoreResult: .success)
        createSut()

        await sut.accept(action: .restoreTapped)

        #expect(await serviceMock.calls == [.restore, .isPro])
    }
}
