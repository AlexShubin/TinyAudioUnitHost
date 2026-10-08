//
//  TargetDeviceResolverSpy.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import AudioSettingsKit

@MainActor
final class TargetDeviceResolverSpy: TargetDeviceResolverType {
    enum Calls: Equatable {
        case resolve(AudioSettings)
    }

    private(set) var calls: [Calls] = []

    var resolveResult: AudioDevice?
    func resolve(_ settings: AudioSettings) -> AudioDevice? {
        calls.append(.resolve(settings))
        return resolveResult
    }
}
