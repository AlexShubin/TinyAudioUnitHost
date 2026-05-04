//
//  AggregateDeviceFactoryMock.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio
@testable import AudioSettingsKit

final class AggregateDeviceFactoryMock: AggregateDeviceFactoryType, @unchecked Sendable {
    enum Calls: Equatable {
        case create(inputUID: String, outputUID: String)
        case destroy(AudioDeviceID)
        case destroyOrphans
    }

    private(set) var calls: [Calls] = []
    var createResult: AudioDeviceID?

    init(createResult: AudioDeviceID? = nil) {
        self.createResult = createResult
    }

    func create(inputUID: String, outputUID: String) -> AudioDeviceID? {
        calls.append(.create(inputUID: inputUID, outputUID: outputUID))
        return createResult
    }

    func destroy(id: AudioDeviceID) {
        calls.append(.destroy(id))
    }

    func destroyOrphans() {
        calls.append(.destroyOrphans)
    }
}
