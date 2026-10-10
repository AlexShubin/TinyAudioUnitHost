//
//  Dependencies.swift
//  CoreAudioGatewayKit
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@MainActor
public struct Dependencies: Sendable {
    public let coreAudioGateway: CoreAudioGatewayType

    public static let live = Dependencies(
        coreAudioGateway: CoreAudioGateway()
    )
}
