//
//  AVCaptureDeviceGateway.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation

protocol AVCaptureDeviceGatewayType: Sendable {
    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus
    func requestAccess(for mediaType: AVMediaType) async -> Bool
}

struct AVCaptureDeviceGateway: AVCaptureDeviceGatewayType {
    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: mediaType)
    }

    func requestAccess(for mediaType: AVMediaType) async -> Bool {
        await AVCaptureDevice.requestAccess(for: mediaType)
    }
}
