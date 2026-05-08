//
//  AUAudioUnitType.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 06.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import Foundation

public protocol AUAudioUnitType: AnyObject, Sendable {
    var fullState: Data? { get set }
    var modifications: AsyncStream<Void> { get }

    @MainActor
    func requestViewController() async -> NSViewController?
}
