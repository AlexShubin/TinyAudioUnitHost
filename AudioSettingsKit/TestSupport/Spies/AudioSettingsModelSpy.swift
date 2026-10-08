//
//  AudioSettingsModelSpy.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import Observation

@MainActor @Observable
public final class AudioSettingsModelSpy: AudioSettingsModelType {
    public enum Calls: Equatable, Sendable {
        case load
        case save(AudioSettings)
    }

    public private(set) var calls: [Calls] = []

    public var settings: AudioSettings = .empty
    public var targetDevice: AudioDevice?
    public var inputDevices: [AudioDevice] = []
    public var outputDevices: [AudioDevice] = []
    public var midiDevices: [MidiDevice] = []
    @ObservationIgnored public weak var delegate: AudioSettingsModelDelegate?

    public init() {}

    public func load() async {
        calls.append(.load)
    }

    public func save(_ settings: AudioSettings) async {
        self.settings = settings
        calls.append(.save(settings))
    }
}
