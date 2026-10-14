//
//  PluginChainSlot.swift
//  SessionKit
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation

struct PluginChainSlot: Equatable {
    let component: AudioUnitComponent
    let state: Data?
}
