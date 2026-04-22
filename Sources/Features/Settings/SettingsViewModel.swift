//
//  SettingsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

enum SettingsViewModelAction {
    case task
}

@MainActor
protocol SettingsViewModelType: Observable {
    var state: SettingsViewState { get }
    func accept(action: SettingsViewModelAction) async
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    private(set) var state = SettingsViewState.initial

    init() {}

    func accept(action: SettingsViewModelAction) async {
        switch action {
        case .task:
            break
        }
    }
}
