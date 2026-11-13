//
//  PresetsObserver.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 13.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import ChannelStripKit
import PresetKit

@MainActor
final class PresetsObserver: PresetsModelDelegate {
    private let channelStrip: ChannelStripModelType

    init(presets: PresetsModelType, channelStrip: ChannelStripModelType) {
        self.channelStrip = channelStrip
        presets.delegate = self
    }

    func presetsDidActivate(preset: Preset) async {
        await channelStrip.replace(with: preset.slots.map { $0.map(PluginSlot.init) })
    }
}

private extension PluginSlot {
    init(_ slot: Preset.Slot) {
        self.init(component: slot.component, state: slot.state, isBypassed: slot.isBypassed, isInstalled: slot.isInstalled)
    }
}
