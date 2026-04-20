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

    func makeNSViewController(context: Context) -> AudioUnitContainerViewController {
        let container = AudioUnitContainerViewController()
        container.audioUnit = audioUnit
        container.onSizeChange = onSizeChange
        return container
    }

    func updateNSViewController(_ controller: AudioUnitContainerViewController, context: Context) {
        controller.onSizeChange = onSizeChange
        if controller.audioUnit !== audioUnit {
            controller.audioUnit = audioUnit
            controller.loadAudioUnitView()
        }
    }
}

final class AudioUnitContainerViewController: NSViewController {
    var audioUnit: AUAudioUnit?
    var onSizeChange: ((CGSize) -> Void)?
    private var auViewController: NSViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadAudioUnitView()
    }

    func loadAudioUnitView() {
        auViewController?.view.removeFromSuperview()
        auViewController?.removeFromParent()
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
        addChild(viewController)
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
        let size = (preferred.width > 0 && preferred.height > 0) ? preferred : auView.fittingSize
        onSizeChange?(size)
    }
}
