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

struct AudioUnitView: NSViewControllerRepresentable {
    let audioUnit: AUAudioUnit
    let onSizeChange: (CGSize) -> Void

    func makeNSViewController(context: Context) -> AudioUnitHostViewController {
        let host = AudioUnitHostViewController()
        host.audioUnit = audioUnit
        host.onSizeChange = onSizeChange
        return host
    }

    func updateNSViewController(_ controller: AudioUnitHostViewController, context: Context) {
        controller.onSizeChange = onSizeChange
        if controller.audioUnit !== audioUnit {
            controller.audioUnit = audioUnit
            controller.loadAudioUnitView()
        }
    }
}

final class AudioUnitHostViewController: NSViewController {
    var audioUnit: AUAudioUnit?
    var onSizeChange: ((CGSize) -> Void)?
    private var auViewController: NSViewController?
    private var sizeObservation: NSKeyValueObservation?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadAudioUnitView()
    }

    func loadAudioUnitView() {
        sizeObservation?.invalidate()
        sizeObservation = nil
        auViewController?.view.removeFromSuperview()
        auViewController = nil

        guard let audioUnit else { return }

        audioUnit.requestViewController { viewController in
            guard let viewController else { return }
            DispatchQueue.main.async { [weak self] in
                self?.install(viewController: viewController)
            }
        }
    }

    private func install(viewController: NSViewController) {
        let auView = viewController.view
        auView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(auView)

        NSLayoutConstraint.activate([
            auView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            auView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            auView.topAnchor.constraint(equalTo: view.topAnchor),
            auView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        auViewController = viewController

        let preferred = viewController.preferredContentSize
        let initialSize = (preferred.width > 0 && preferred.height > 0) ? preferred : auView.fittingSize
        onSizeChange?(initialSize)

        sizeObservation = viewController.observe(\.preferredContentSize, options: [.new]) { [weak self] vc, _ in
            let size = vc.preferredContentSize
            guard size.width > 0 && size.height > 0 else { return }
            DispatchQueue.main.async {
                self?.onSizeChange?(size)
            }
        }
    }

    deinit {
        sizeObservation?.invalidate()
    }
}
