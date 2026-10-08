//
//  NavigationModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

@MainActor
protocol NavigationModelType: AnyObject, Observable {
    var presetsDestination: PresetsDestination? { get set }
}

enum PresetsDestination: Equatable {
    case presetNameDialog(PresetNameDialogMode)
    case proWindow
}

@MainActor @Observable
final class NavigationModel: NavigationModelType {
    var presetsDestination: PresetsDestination?
}
