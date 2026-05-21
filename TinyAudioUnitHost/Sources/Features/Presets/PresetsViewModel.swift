//
//  PresetsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation
import PresetKit
import PurchasesKit

@MainActor
protocol PresetsViewModelType: AnyObject, Observable {
    var presets: [Preset] { get }
    var activeName: String? { get }
    var isInteractionDisabled: Bool { get }
    var isSaveAsButtonDisabled: Bool { get }
    var presentedPresetNameDialog: PresetNameDialogMode? { get }
    var openProWindowRequest: UUID? { get }
    func accept(action: PresetsAction) async
}

enum PresetsAction: Sendable, Equatable {
    case selected(name: String)
    case renameTapped(name: String)
    case deleteTapped(name: String)
    case saveAsTapped
    case dismissDialog
}

@MainActor @Observable
final class PresetsViewModel: PresetsViewModelType {
    private static let freeTierPresetLimit = 2

    private(set) var presentedPresetNameDialog: PresetNameDialogMode?
    private(set) var openProWindowRequest: UUID?

    var presets: [Preset] {
        isPro ? session.presets : Array(session.presets.prefix(Self.freeTierPresetLimit))
    }
    var activeName: String? { session.activeName }
    var isInteractionDisabled: Bool { !session.content.isOperable }
    var isSaveAsButtonDisabled: Bool { !session.content.isLoaded }

    private var isPro: Bool = false

    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private let purchasesService: PurchasesServiceType
    @ObservationIgnored private let eventBus: SessionEventBusType
    @ObservationIgnored private var isProListener: Task<Void, Never>?
    @ObservationIgnored private var sessionEventsListener: Task<Void, Never>?

    init(
        session: SessionManagerType,
        purchasesService: PurchasesServiceType,
        eventBus: SessionEventBusType
    ) {
        self.session = session
        self.purchasesService = purchasesService
        self.eventBus = eventBus
        isProListener = Task { @MainActor [weak self, purchasesService] in
            for await value in await purchasesService.makeIsProStream() {
                self?.isPro = value
            }
        }
        let stream = eventBus.makeEventStream()
        sessionEventsListener = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self else { return }
                switch event {
                case .saveAsRequested:
                    await self.accept(action: .saveAsTapped)
                case .saved, .restored:
                    break  // owned by Host feature
                }
            }
        }
    }

    deinit {
        isProListener?.cancel()
        sessionEventsListener?.cancel()
    }

    func accept(action: PresetsAction) async {
        switch action {
        case .selected(let name):
            await session.selectPreset(name: name)
        case .renameTapped(let name):
            presentedPresetNameDialog = .rename(currentName: name)
        case .deleteTapped(let name):
            session.deletePreset(name: name)
        case .saveAsTapped:
            if isPro || session.presets.count < Self.freeTierPresetLimit {
                presentedPresetNameDialog = .saveAs
            } else {
                openProWindowRequest = UUID()
            }
        case .dismissDialog:
            presentedPresetNameDialog = nil
        }
    }
}
