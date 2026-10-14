//
//  SetupState.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public enum SetupState: Sendable, Equatable {
    case checking
    case unmet(Set<SetupRequirement>)
    case met
}

public enum SetupRequirement: Sendable, Equatable, Hashable {
    case microphonePermission
    case noOutputDevice
    case savedOutputDeviceUnavailable(name: String)
}
