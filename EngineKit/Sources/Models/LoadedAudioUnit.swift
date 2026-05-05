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

    public func waitForModification() async {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let token = auAudioUnit.parameterTree?.token(byAddingParameterObserver: { _, _ in
            continuation.yield()
        })
        defer {
            if let token { auAudioUnit.parameterTree?.removeParameterObserver(token) }
            continuation.finish()
        }
        for await _ in stream { break }
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
