//
//  CoreMidiGatewayMock.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 05.06.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
@testable import EngineKit

final class CoreMidiGatewayMock: CoreMidiGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
        case createClient(String)
        case createInputPort(UInt32, String)
        case source(Int)
        case connect(UInt32, UInt32)
        case disposePort(UInt32)
    }

    private(set) var calls: [Calls] = []
    var createClientResult: UInt32? = 1
    var createInputPortResult: UInt32? = 1
    var sources: [UInt32] = []
    private(set) var createInputPortAudioUnit: AUAudioUnitWrapper?
    private let setupChanges = AsyncStream<Void>.makeStream()

    func createClient(name: String) -> (client: UInt32, setupChanges: AsyncStream<Void>)? {
        calls.append(.createClient(name))
        guard let createClientResult else { return nil }
        return (createClientResult, setupChanges.stream)
    }

    func createInputPort(
        client: UInt32,
        name: String,
        audioUnit: AUAudioUnitWrapper
    ) -> UInt32? {
        createInputPortAudioUnit = audioUnit
        calls.append(.createInputPort(client, name))
        return createInputPortResult
    }

    var sourceCount: Int {
        sources.count
    }

    func source(at index: Int) -> UInt32 {
        calls.append(.source(index))
        return sources[index]
    }

    func connect(source: UInt32, to port: UInt32) {
        calls.append(.connect(source, port))
    }

    func disposePort(_ port: UInt32) {
        calls.append(.disposePort(port))
    }

    func emitSetupChanged() {
        setupChanges.continuation.yield()
    }

    func finishSetupChanges() {
        setupChanges.continuation.finish()
    }
}
