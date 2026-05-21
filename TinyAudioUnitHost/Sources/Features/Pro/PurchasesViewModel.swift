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
    var productInfo: ProProductInfo? { get }
    var phase: PurchasesPhase { get }
    var errorMessage: String? { get }
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

    @ObservationIgnored private let purchasesService: PurchasesServiceType

    init(purchasesService: PurchasesServiceType) {
        self.purchasesService = purchasesService
    }

    func accept(action: PurchasesViewAction) async {
        switch action {
        case .task:
            isPro = await purchasesService.isPro
            productInfo = await purchasesService.productInfo
        case .buyTapped:
            phase = .purchasing
            errorMessage = nil
            let result = await purchasesService.purchase()
            errorMessage = message(for: result)
            isPro = await purchasesService.isPro
            phase = .idle
        case .restoreTapped:
            phase = .restoring
            errorMessage = nil
            let result = await purchasesService.restore()
            errorMessage = message(for: result)
            isPro = await purchasesService.isPro
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
