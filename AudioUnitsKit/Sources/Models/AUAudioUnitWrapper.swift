//
//  AUAudioUnitWrapper.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 06.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
@preconcurrency import CoreAudioKit

public final class AUAudioUnitWrapper: Equatable, Sendable {
    public static func == (lhs: AUAudioUnitWrapper, rhs: AUAudioUnitWrapper) -> Bool {
        lhs === rhs
    }

    private let au: AUAudioUnit?
    private let detachedState: Data?

    public init(_ au: AUAudioUnit) {
        self.au = au
        self.detachedState = nil
    }

    /// Headless wrapper with no live audio unit, for tests that only need a `fullState` value.
    public init(fullState: Data? = nil) {
        self.au = nil
        self.detachedState = fullState
    }

    public var fullState: Data? {
        get { au?.fullState?.binaryPlist ?? detachedState }
        set { au?.fullState = newValue?.asStringAnyDictionary }
    }

    public var scheduleMIDIEventListBlock: AUMIDIEventListBlock? {
        au?.scheduleMIDIEventListBlock
    }

    @MainActor
    public func requestViewController() async -> NSViewController? {
        guard let au else { return nil }
        return await withCheckedContinuation { continuation in
            au.requestViewController { continuation.resume(returning: $0) }
        }
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
