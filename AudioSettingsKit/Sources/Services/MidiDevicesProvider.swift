//
//  MidiDevicesProvider.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol MidiDevicesProviderType: Sendable {
    var devices: [MidiDevice] { get }
}

struct MidiDevicesProvider: MidiDevicesProviderType {
    private let gateway: CoreMidiGatewayType

    init(gateway: CoreMidiGatewayType) {
        self.gateway = gateway
    }

    var devices: [MidiDevice] {
        (0..<gateway.sourceCount).compactMap { index in
            let ref = gateway.source(at: index)
            guard !gateway.isOffline(ref),
                  let uid = gateway.uid(of: ref),
                  let name = gateway.displayName(of: ref)
            else { return nil }
            return MidiDevice(ref: ref, uid: uid, name: name)
        }
    }
}
