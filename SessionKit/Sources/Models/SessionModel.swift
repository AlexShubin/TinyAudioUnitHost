//
//  SessionModel.swift
//  SessionKit
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import Observation

@MainActor
public protocol SessionModelType: AnyObject, Observable, Sendable {
    var slots: [PluginSlotContent] { get }
    var selectedIndex: Int { get }
    var isBusy: Bool { get }

    func updateHardwareSettings(_ settings: SessionHardwareSettings?) async
    func load(component: AudioUnitComponent, at index: Int) async
    func unload(at index: Int) async
    func setBypassed(_ isBypassed: Bool, at index: Int)
    func select(index: Int)
    func replace(with chain: [PluginSlot?]) async
}

public enum PluginSlotContent: Sendable, Equatable {
    case empty
    case loading(component: AudioUnitComponent)
    case loaded(audioUnit: LoadedAudioUnit, isBypassed: Bool)
    case failed(component: AudioUnitComponent, state: Data?, isBypassed: Bool, message: String)
}

@MainActor @Observable
final class SessionModel: SessionModelType {
    private(set) var slots: [PluginSlotContent] = []
    private(set) var selectedIndex = 0

    var isBusy: Bool {
        slots.contains { slot in
            if case .loading = slot { true } else { false }
        }
    }

    @ObservationIgnored private let channelStrip: ChannelStripType

    init(channelStrip: ChannelStripType) {
        self.channelStrip = channelStrip
    }

    func updateHardwareSettings(_ settings: SessionHardwareSettings?) async {
        await channelStrip.updateHardwareSettings(settings)
    }

    func load(component: AudioUnitComponent, at index: Int) async {
        selectedIndex = index
        replaceSlot(at: index, with: .loading(component: component))
        do {
            let audioUnit = try await channelStrip.load(slot: ChannelStripSlot(component: component, state: nil), at: index)
            finishLoadingSlot(at: index, with: .loaded(audioUnit: audioUnit, isBypassed: false))
        } catch {
            finishLoadingSlot(at: index, with: .failed(component: component, state: nil, isBypassed: false, message: error.message))
        }
    }

    func unload(at index: Int) async {
        replaceSlot(at: index, with: .empty)
        await channelStrip.unload(at: index)
    }

    func setBypassed(_ isBypassed: Bool, at index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index] = slots[index].applyingBypass(isBypassed)
    }

    func select(index: Int) {
        selectedIndex = index
    }

    func replace(with chain: [PluginSlot?]) async {
        replaceSlots(with: chain.map { $0?.initialContent ?? .empty })
        let results = await channelStrip.load(slots: chain.map { $0?.channelStripSlot })
        for (index, (pluginSlot, result)) in zip(chain, results).enumerated() {
            guard let pluginSlot, let result else { continue }
            finishLoadingSlot(at: index, with: pluginSlot.content(for: result))
        }
    }

    private func finishLoadingSlot(at index: Int, with content: PluginSlotContent) {
        guard slots.indices.contains(index), case .loading = slots[index] else { return }
        replaceSlot(at: index, with: content)
    }

    private func replaceSlot(at index: Int, with content: PluginSlotContent) {
        guard index <= slots.count else { return }
        var updated = slots
        if index == updated.count {
            updated.append(content)
        } else {
            updated[index] = content
        }
        replaceSlots(with: updated)
    }

    private func replaceSlots(with contents: [PluginSlotContent]) {
        var trimmed = contents
        while trimmed.last == .empty {
            trimmed.removeLast()
        }
        slots = trimmed
        selectFilledSlotIfNeeded()
    }

    private func selectFilledSlotIfNeeded() {
        let selected = slots.indices.contains(selectedIndex) ? slots[selectedIndex] : .empty
        guard selected == .empty, let firstFilled = slots.firstIndex(where: { $0 != .empty }) else { return }
        selectedIndex = firstFilled
    }
}

private extension PluginSlotContent {
    func applyingBypass(_ isBypassed: Bool) -> PluginSlotContent {
        guard case .loaded(let audioUnit, _) = self else { return self }
        audioUnit.isBypassed = isBypassed
        return .loaded(audioUnit: audioUnit, isBypassed: isBypassed)
    }
}

private extension PluginSlot {
    static let notInstalledMessage = "This plug-in isn't installed."

    var initialContent: PluginSlotContent {
        isInstalled ? .loading(component: component) : failed(message: Self.notInstalledMessage)
    }

    var channelStripSlot: ChannelStripSlot? {
        isInstalled ? ChannelStripSlot(component: component, state: state) : nil
    }

    func content(for result: Result<LoadedAudioUnit, ChannelStripLoadError>) -> PluginSlotContent {
        switch result {
        case .success(let audioUnit):
            audioUnit.isBypassed = isBypassed
            return .loaded(audioUnit: audioUnit, isBypassed: isBypassed)
        case .failure(let error):
            return failed(message: error.message)
        }
    }

    func failed(message: String) -> PluginSlotContent {
        .failed(component: component, state: state, isBypassed: isBypassed, message: message)
    }
}

private extension ChannelStripLoadError {
    var message: String {
        switch self {
        case .audioUnitInstantiationFailed: return "Couldn't load this audio unit."
        }
    }
}
