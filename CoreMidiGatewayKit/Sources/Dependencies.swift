//
//  Dependencies.swift
//  CoreMidiGatewayKit
//
//  Created by Alex Shubin on 09.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@MainActor
public struct Dependencies: Sendable {
    public let coreMidiGateway: CoreMidiGatewayType

    public static let live = Dependencies(
        coreMidiGateway: CoreMidiGateway()
    )
}
