//
//  AUAudioUnitType.swift
//  EngineKit
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

    func onChange(_ block: @escaping @Sendable () -> Void)
}

final class AUAudioUnitWrapper: AUAudioUnitType, @unchecked Sendable {
    private let au: AUAudioUnit

    init(_ au: AUAudioUnit) {
        self.au = au
    }

    var fullState: Data? {
        get { au.fullState?.binaryPlist }
        set { au.fullState = newValue?.asStringAnyDictionary }
    }

    @MainActor
    func requestViewController() async -> NSViewController? {
        await withCheckedContinuation { continuation in
            au.requestViewController { continuation.resume(returning: $0) }
        }
    }

    func onChange(_ block: @escaping @Sendable () -> Void) {
        var token: AUParameterObserverToken?
        token = au.parameterTree?.token(byAddingParameterObserver: { [weak au] _, _ in
            block()
            if let token {
                au?.parameterTree?.removeParameterObserver(token)
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
