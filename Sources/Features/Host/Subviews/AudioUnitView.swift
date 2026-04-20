//
//  AudioUnitView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import CoreAudioKit
import SwiftUI

struct AudioUnitView: View {
    let audioUnit: AUAudioUnit
    @State private var controller: NSViewController?
    @State private var size = CGSize(width: 480, height: 320)

    var body: some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay {
                if let controller {
                    Representable(controller: controller)
                }
            }
            .task(id: ObjectIdentifier(audioUnit)) {
                controller = nil
                guard let vc = await audioUnit.requestViewControllerAsync() else { return }
                controller = vc

                for await newSize in vc.preferredContentSizeStream() {
                    size = newSize
                }
            }
    }
}

private struct Representable: NSViewControllerRepresentable {
    let controller: NSViewController

    func makeNSViewController(context: Context) -> NSViewController { controller }
    func updateNSViewController(_ controller: NSViewController, context: Context) {}
}

private extension AUAudioUnit {
    @MainActor
    func requestViewControllerAsync() async -> NSViewController? {
        await withCheckedContinuation { continuation in
            requestViewController { continuation.resume(returning: $0) }
        }
    }
}

private extension NSViewController {
    @MainActor
    func preferredContentSizeStream() -> AsyncStream<CGSize> {
        AsyncStream { continuation in
            continuation.yield(preferredContentSize)
            let observation = observe(\.preferredContentSize, options: [.new]) { vc, _ in
                Task { @MainActor in
                    continuation.yield(vc.preferredContentSize)
                }
            }
            continuation.onTermination = { _ in
                observation.invalidate()
            }
        }
    }
}
