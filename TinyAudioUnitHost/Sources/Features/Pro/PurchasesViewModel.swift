//
//  PurchasesViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation
import PurchasesKit

@MainActor
protocol PurchasesViewModelType: AnyObject, Observable {
    var state: PurchasesViewState { get }
    func accept(action: PurchasesViewAction) async
}

@MainActor @Observable
final class PurchasesViewModel: PurchasesViewModelType {
    private(set) var state = PurchasesViewState(
        isPro: false,
        productInfo: nil,
        phase: .idle,
        errorMessage: nil
    )

    @ObservationIgnored private let purchasesService: PurchasesServiceType

    init(purchasesService: PurchasesServiceType) {
        self.purchasesService = purchasesService
    }

    func accept(action: PurchasesViewAction) async {
        switch action {
        case .task:
            state.isPro = await purchasesService.isPro
            state.productInfo = await purchasesService.productInfo
        case .buyTapped:
            state.phase = .purchasing
            state.errorMessage = nil
            let result = await purchasesService.purchase()
            state.errorMessage = errorMessage(for: result)
            state.isPro = await purchasesService.isPro
            state.phase = .idle
        case .restoreTapped:
            state.phase = .restoring
            state.errorMessage = nil
            let result = await purchasesService.restore()
            state.errorMessage = errorMessage(for: result)
            state.isPro = await purchasesService.isPro
            state.phase = .idle
        }
    }

    private func errorMessage(for result: PurchaseResult) -> String? {
        switch result {
        case .success, .userCancelled, .pending:
            return nil
        case .productUnavailable:
            return "This product isn't available right now."
        case .verificationFailed:
            return "Purchase couldn't be verified."
        case .unknownError(let message):
            return message
        }
    }
}
