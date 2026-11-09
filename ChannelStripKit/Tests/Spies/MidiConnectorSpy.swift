//
//  MidiConnectorSpy.swift
//  ChannelStripKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
@testable import ChannelStripKit

final class MidiConnectorSpy: MidiConnectorType, @unchecked Sendable {
    enum Calls: Equatable {
        case connect(LoadedAudioUnit, ChannelStripHardwareSettings.Midi)
        case disconnect
        case reconnect(ChannelStripHardwareSettings.Midi)
    }

    private(set) var calls: [Calls] = []

    func connect(_ audioUnit: LoadedAudioUnit, settings: ChannelStripHardwareSettings.Midi) {
        calls.append(.connect(audioUnit, settings))
    }

    func disconnect() {
        calls.append(.disconnect)
    }

    func reconnect(settings: ChannelStripHardwareSettings.Midi) {
        calls.append(.reconnect(settings))
    }
}
