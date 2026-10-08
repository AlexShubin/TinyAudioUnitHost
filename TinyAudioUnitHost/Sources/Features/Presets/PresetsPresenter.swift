//
//  PresetsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import PurchasesKit

@MainActor
protocol PresetsPresenterType {
    var presets: [String] { get }
    var activeName: String? { get }
    var isInteractionDisabled: Bool { get }
    var isSaveAsButtonDisabled: Bool { get }
    var presentedDialog: PresetNameDialogMode? { get }
    var isProWindowRequested: Bool { get }
    func select(name: String) async
    func rename(name: String)
    func delete(name: String)
    func saveAs()
    func dismissDestination()
}

@MainActor
struct PresetsPresenter: PresetsPresenterType {
    private static let freeTierPresetLimit = 2

    var presets: [String] {
        purchases.state.isPro ? session.presets : Array(session.presets.prefix(Self.freeTierPresetLimit))
    }
    var activeName: String? { session.activeName }
    var isInteractionDisabled: Bool { !session.content.isOperable }
    var isSaveAsButtonDisabled: Bool { !session.content.isLoaded }

    var presentedDialog: PresetNameDialogMode? {
        if case .presetNameDialog(let mode) = navigation.presetsDestination {
            return mode
        }
        return nil
    }

    var isProWindowRequested: Bool { navigation.presetsDestination == .proWindow }

    private let session: SessionModelType
    private let purchases: PurchasesModelType
    private let navigation: NavigationModelType

    init(
        session: SessionModelType,
        purchases: PurchasesModelType,
        navigation: NavigationModelType,
        saveAsCommandBinder: CommandBinderType
    ) {
        self.session = session
        self.purchases = purchases
        self.navigation = navigation
        let presenter = self
        saveAsCommandBinder.bind { presenter.saveAs() }
    }

    func select(name: String) async {
        await session.selectPreset(name: name)
    }

    func rename(name: String) {
        navigation.presetsDestination = .presetNameDialog(.rename(currentName: name))
    }

    func delete(name: String) {
        session.deletePreset(name: name)
    }

    func saveAs() {
        if purchases.state.isPro || session.presets.count < Self.freeTierPresetLimit {
            navigation.presetsDestination = .presetNameDialog(.saveAs)
        } else {
            navigation.presetsDestination = .proWindow
        }
    }

    func dismissDestination() {
        navigation.presetsDestination = nil
    }
}
