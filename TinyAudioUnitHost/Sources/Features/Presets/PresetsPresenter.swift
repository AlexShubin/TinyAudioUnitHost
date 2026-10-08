//
//  PresetsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
import PresetKit
import PurchasesKit

@MainActor @Observable
final class PresetsPresenter {
    private static let freeTierPresetLimit = 2

    var presets: [String] {
        purchases.state.isPro ? session.presets : Array(session.presets.prefix(Self.freeTierPresetLimit))
    }
    var activeName: String? { session.activeName }
    var isInteractionDisabled: Bool { !session.content.isOperable }
    var isSaveAsButtonDisabled: Bool { !session.content.isLoaded }

    var presentedDialog: PresetNameDialogMode? {
        get {
            if case .presetNameDialog(let mode) = destination {
                return mode
            }
            return nil
        }
        set {
            destination = newValue.map { .presetNameDialog($0) }
        }
    }

    var isProWindowRequested: Bool { destination == .proWindow }

    private var destination: PresetsDestination?
    private let session: SessionModelType
    private let purchases: PurchasesModelType
    private let saveAsCommandBinder: CommandBinderType

    init(
        session: SessionModelType,
        purchases: PurchasesModelType,
        saveAsCommandBinder: CommandBinderType
    ) {
        self.session = session
        self.purchases = purchases
        self.saveAsCommandBinder = saveAsCommandBinder
    }

    func task() {
        saveAsCommandBinder.bind { [weak self] in self?.saveAs() }
    }

    func select(name: String) async {
        await session.selectPreset(name: name)
    }

    func rename(name: String) {
        destination = .presetNameDialog(.rename(currentName: name))
    }

    func delete(name: String) {
        session.deletePreset(name: name)
    }

    func saveAs() {
        if purchases.state.isPro || session.presets.count < Self.freeTierPresetLimit {
            destination = .presetNameDialog(.saveAs)
        } else {
            destination = .proWindow
        }
    }

    func proWindowOpened() {
        destination = nil
    }
}

enum PresetsDestination: Equatable {
    case presetNameDialog(PresetNameDialogMode)
    case proWindow
}
