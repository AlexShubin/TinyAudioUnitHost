//
//  AudioSettingsModelDelegateSpy.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

@MainActor
public final class AudioSettingsModelDelegateSpy: AudioSettingsModelDelegate {
    public enum Calls: Equatable, Sendable {
        case audioSettingsDidChange
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var onAudioSettingsDidChange: (@MainActor () -> Void)?
    public func audioSettingsDidChange() async {
        onAudioSettingsDidChange?()
        calls.append(.audioSettingsDidChange)
    }
}
