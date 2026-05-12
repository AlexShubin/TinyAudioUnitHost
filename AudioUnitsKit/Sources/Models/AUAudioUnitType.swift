//
//  AUAudioUnitType.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 06.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import CoreAudioKit

public protocol AUAudioUnitType: AnyObject, Sendable {
    var fullState: Data? { get set }

    @MainActor
    func requestViewController() async -> NSViewController?
}

public final class AUAudioUnitWrapper: AUAudioUnitType, @unchecked Sendable {
    private let au: AUAudioUnit

    public init(_ au: AUAudioUnit) {
        self.au = au
    }

    public var fullState: Data? {
        get { au.fullState?.binaryPlist }
        set { au.fullState = newValue?.asStringAnyDictionary }
    }

    @MainActor
    public func requestViewController() async -> NSViewController? {
        await withCheckedContinuation { continuation in
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
