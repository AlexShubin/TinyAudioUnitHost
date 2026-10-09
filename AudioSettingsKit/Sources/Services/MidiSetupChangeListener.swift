//
//  MidiSetupChangeListener.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import CoreMidiGatewayKit

public protocol MidiSetupChangeListenerType: Sendable {
    func observeChanges(_ handler: @escaping @Sendable () async -> Void) -> Cancellation
}

struct MidiSetupChangeListener: MidiSetupChangeListenerType {
    private let gateway: CoreMidiGatewayType

    init(gateway: CoreMidiGatewayType) {
        self.gateway = gateway
    }

    func observeChanges(_ handler: @escaping @Sendable () async -> Void) -> Cancellation {
        guard let client = gateway.createClient(name: "TinyAUHost-AudioSettings", onSetupChange: handler)
        else { return Cancellation {} }
        return Cancellation { gateway.disposeClient(client) }
    }
}
