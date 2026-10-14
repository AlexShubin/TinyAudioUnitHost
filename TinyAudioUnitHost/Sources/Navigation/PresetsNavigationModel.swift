//
//  PresetsNavigationModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

@MainActor
protocol PresetsNavigationModelType: AnyObject, Observable, Sendable {
    var presentedNameDialogMode: PresetNameDialogMode? { get set }
}

enum PresetNameDialogMode: Sendable, Equatable, Hashable, Identifiable {
    case saveAs
    case rename(currentName: String)

    var id: Self { self }
}

@MainActor @Observable
final class PresetsNavigationModel: PresetsNavigationModelType {
    var presentedNameDialogMode: PresetNameDialogMode?
}
