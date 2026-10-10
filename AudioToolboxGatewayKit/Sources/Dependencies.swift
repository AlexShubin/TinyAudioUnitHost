//
//  Dependencies.swift
//  AudioToolboxGatewayKit
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@MainActor
public struct Dependencies: Sendable {
    public let audioUnitGateway: AudioUnitGatewayType

    public static let live = Dependencies(
        audioUnitGateway: AudioUnitGateway()
    )
}
