//
//  AudioUnitView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import SwiftUI

struct AudioUnitView: View {
    let audioUnit: LoadedAudioUnit
    @State private var loadState: LoadState = .loading
    @State private var size = CGSize(width: 480, height: 320)

    var body: some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay {
                switch loadState {
                case .loading:
                    EmptyView()
                case .loaded(let controller):
                    Representable(controller: controller)
                case .unavailable:
                    Text("This audio unit has no custom interface.")
                        .foregroundStyle(.secondary)
                }
            }
            .task(id: ObjectIdentifier(audioUnit.audioUnit)) {
                loadState = .loading
                guard let vc = await audioUnit.audioUnit.requestViewController() else {
                    loadState = .unavailable
                    return
                }
                loadState = .loaded(vc)

                for await newSize in vc.preferredContentSizeStream() {
                    size = newSize
                }
            }
    }

    private enum LoadState {
        case loading
        case loaded(NSViewController)
        case unavailable
    }
}

private struct Representable: NSViewControllerRepresentable {
    let controller: NSViewController

    func makeNSViewController(context: Context) -> NSViewController { controller }
    func updateNSViewController(_ controller: NSViewController, context: Context) {}
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
