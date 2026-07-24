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
        case createInputPort(UInt32, String, AUAudioUnitWrapper)
        case connect(UInt32, UInt32)
        case disconnect(UInt32, UInt32)
        case disposePort(UInt32)
    }

    private(set) var calls: [Calls] = []

    var createClientResult: UInt32? = 1
    var setupChangesStream = AsyncStream<Void>.makeStream()
    func createClient(name: String) -> (client: UInt32, setupChanges: AsyncStream<Void>)? {
        calls.append(.createClient(name))
        guard let createClientResult else { return nil }
        return (createClientResult, setupChangesStream.stream)
    }

    var createInputPortResult: UInt32? = 1
    func createInputPort(
        client: UInt32,
        name: String,
        audioUnit: AUAudioUnitWrapper
    ) -> UInt32? {
        calls.append(.createInputPort(client, name, audioUnit))
        return createInputPortResult
    }

    func connect(source: UInt32, to port: UInt32) {
        calls.append(.connect(source, port))
    }

    func disconnect(source: UInt32, from port: UInt32) {
        calls.append(.disconnect(source, port))
    }

    func disposePort(_ port: UInt32) {
        calls.append(.disposePort(port))
    }
}
