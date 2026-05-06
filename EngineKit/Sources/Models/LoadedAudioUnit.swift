//
//  LoadedAudioUnit.swift
//  EngineKit
//
//  Created by Alex Shubin on 21.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioUnitsKit
import CoreAudioKit

public struct LoadedAudioUnit: Sendable, Equatable {
    public let component: AudioUnitComponent
    nonisolated(unsafe) private let auAudioUnit: AUAudioUnit

    public init(
        component: AudioUnitComponent,
        auAudioUnit: AUAudioUnit
    ) {
        self.component = component
        self.auAudioUnit = auAudioUnit
    }

    @MainActor
    public func requestViewController() async -> NSViewController? {
        await withCheckedContinuation { continuation in
            auAudioUnit.requestViewController { continuation.resume(returning: $0) }
        }
    }

    public var snapshot: Data? {
        auAudioUnit.fullState?.binaryPlist
    }

    public func restore(_ data: Data) {
        guard let state = data.asStringAnyDictionary else { return }
        auAudioUnit.fullState = state
    }

    public func modification(block: @escaping @Sendable () -> Void) {
        var token: AUParameterObserverToken?
        token = auAudioUnit.parameterTree?.token(byAddingParameterObserver: { [weak auAudioUnit] _, _ in
            block()
            if let token {
                auAudioUnit?.parameterTree?.removeParameterObserver(token)
            }
        })
    }
}

private extension [String: Any] {
    var binaryPlist: Data? {
        try? PropertyListSerialization.data(fromPropertyList: self, format: .binary, options: 0)
    }
}

private extension Data {
    var asStringAnyDictionary: [String: Any]? {
        let plist = try? PropertyListSerialization.propertyList(from: self, options: [], format: nil)
        return plist as? [String: Any]
    }
}
