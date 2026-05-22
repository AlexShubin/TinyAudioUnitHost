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
    var isPurchasing: Bool { get }
    var isUpgradeButtonDisabled: Bool { get }
    var isRestoreButtonDisabled: Bool { get }
    func accept(action: PurchasesViewAction) async
}

enum PurchasesPhase: Sendable, Equatable {
    case idle
    case purchasing
    case restoring
}

enum PurchasesViewAction: Sendable, Equatable {
    case task
    case buyTapped
    case restoreTapped
}

@MainActor @Observable
final class PurchasesViewModel: PurchasesViewModelType {
    private(set) var isPro: Bool = false
    private(set) var productInfo: ProProductInfo?
    private(set) var phase: PurchasesPhase = .idle
    private(set) var errorMessage: String?

    var priceLabel: String? { productInfo?.displayPrice }
    var isPurchasing: Bool { phase == .purchasing }
    var isUpgradeButtonDisabled: Bool { phase != .idle }
    var isRestoreButtonDisabled: Bool { phase == .restoring }

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
            productInfo = await purchasesService.productInfo
        case .buyTapped:
            phase = .purchasing
            errorMessage = nil
            let result = await purchasesService.purchase()
            errorMessage = message(for: result)
            phase = .idle
        case .restoreTapped:
            phase = .restoring
            errorMessage = nil
            let result = await purchasesService.restore()
            errorMessage = message(for: result)
            phase = .idle
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
