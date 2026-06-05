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
    var isPro: Bool { get }
    var priceLabel: String? { get }
    var errorMessage: String? { get }
    var purchaseButtonState: PurchaseButtonState { get }
    var isRestoreButtonDisabled: Bool { get }
    func accept(action: PurchasesViewAction) async
}

enum PurchaseButtonState: Sendable, Equatable {
    case enabled
    case purchasing
    case disabled
}

enum PurchasesViewAction: Sendable, Equatable {
    case task
    case buyTapped
    case restoreTapped
}

@MainActor @Observable
final class PurchasesViewModel: PurchasesViewModelType {
    private(set) var isPro: Bool = false
    private(set) var priceLabel: String?
    private(set) var purchaseButtonState: PurchaseButtonState = .enabled
    private(set) var isRestoreButtonDisabled: Bool = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let purchasesService: PurchasesServiceType
    @ObservationIgnored private var isProListener: Task<Void, Never>?

    init(purchasesService: PurchasesServiceType) {
        self.purchasesService = purchasesService
        isProListener = Task { @MainActor [weak self, purchasesService] in
            for await value in await purchasesService.makeIsProStream() {
                self?.isPro = value
            }
        }
    }

    deinit {
        isProListener?.cancel()
    }

    func accept(action: PurchasesViewAction) async {
        switch action {
        case .task:
            priceLabel = await purchasesService.productInfo?.displayPrice
        case .buyTapped:
            purchaseButtonState = .purchasing
            isRestoreButtonDisabled = true
            errorMessage = nil
            let result = await purchasesService.purchase()
            errorMessage = message(for: result)
            purchaseButtonState = .enabled
            isRestoreButtonDisabled = false
        case .restoreTapped:
            purchaseButtonState = .disabled
            isRestoreButtonDisabled = true
            errorMessage = nil
            let result = await purchasesService.restore()
            errorMessage = message(for: result)
            purchaseButtonState = .enabled
            isRestoreButtonDisabled = false
        }
    }

    private func message(for result: PurchaseResult) -> String? {
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
