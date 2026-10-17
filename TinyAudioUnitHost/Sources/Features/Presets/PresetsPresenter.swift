//
//  PresetsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
import SessionKit

@MainActor @Observable
final class PresetsPresenter {
    var presets: [String] { session.presets }
    var activeName: String? { session.activePresetName }
    var isInteractionDisabled: Bool { session.isBusy }
    var isSaveAsButtonDisabled: Bool { !session.canSavePreset }

    var presentedNameDialogMode: PresetNameDialogMode? {
        get { presetsNavigation.presentedNameDialogMode }
        set { presetsNavigation.presentedNameDialogMode = newValue }
    }

    private let session: SessionModelType
    private let presetsNavigation: PresetsNavigationModelType

    init(
        session: SessionModelType,
        presetsNavigation: PresetsNavigationModelType
    ) {
        self.session = session
        self.presetsNavigation = presetsNavigation
    }

    func select(name: String) async {
        await session.selectPreset(name: name)
    }

    func rename(name: String) {
        presetsNavigation.presentedNameDialogMode = .rename(currentName: name)
    }

    func delete(name: String) {
        session.deletePreset(name: name)
    }

    func saveAs() {
        presetsNavigation.presentedNameDialogMode = .saveAs
    }
}
