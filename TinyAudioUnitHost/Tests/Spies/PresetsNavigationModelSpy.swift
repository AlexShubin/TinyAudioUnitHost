//
//  PresetsNavigationModelSpy.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
@testable import TinyAudioUnitHost

@MainActor @Observable
final class PresetsNavigationModelSpy: PresetsNavigationModelType {
    var presentedNameDialogMode: PresetNameDialogMode?
}
