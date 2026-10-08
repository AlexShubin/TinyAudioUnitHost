//
//  NavigationModelSpy.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
@testable import TinyAudioUnitHost

@MainActor @Observable
final class NavigationModelSpy: NavigationModelType {
    var presetsDestination: PresetsDestination?
}
