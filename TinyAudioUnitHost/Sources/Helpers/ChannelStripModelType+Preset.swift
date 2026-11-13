//
//  ChannelStripModelType+Preset.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 13.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import ChannelStripKit
import PresetKit

extension ChannelStripModelType {
    var isSavable: Bool {
        !isBusy && slots.contains { slot in
            if case .loaded = slot { true } else { false }
        }
    }

    var preset: Preset? {
        guard isSavable else { return nil }
        return Preset(slots: slots.map(\.presetSlot))
    }
}

private extension PluginSlotContent {
    var presetSlot: Preset.Slot? {
        switch self {
        case .empty, .loading:
            nil
        case .loaded(let audioUnit, let isBypassed):
            Preset.Slot(component: audioUnit.component, state: audioUnit.fullState, isBypassed: isBypassed, isInstalled: true)
        case .failed(let component, let state, let isBypassed, _):
            Preset.Slot(component: component, state: state, isBypassed: isBypassed, isInstalled: true)
        }
    }
}
