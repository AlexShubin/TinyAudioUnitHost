//
//  RawTargetDevice.swift
//  StorageKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct RawTargetDevice: Sendable, Equatable, Codable {
    public var input: RawDeviceSettings
    public var output: RawDeviceSettings

    public init(
        input: RawDeviceSettings = .empty,
        output: RawDeviceSettings = .empty
    ) {
        self.input = input
        self.output = output
    }

    public static let empty = RawTargetDevice()
}
