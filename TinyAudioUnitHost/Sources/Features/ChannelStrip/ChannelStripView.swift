//
//  ChannelStripView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct ChannelStripView: View {
    @State var presenter: ChannelStripPresenter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            section(presenter.sourceTitle) {
                slot(presenter.sourceSlot)
            }
            if !presenter.insertSlots.isEmpty {
                section("Inserts") {
                    VStack(spacing: 6) {
                        ForEach(presenter.insertSlots) { state in
                            slot(state)
                        }
                    }
                    .background {
                        Capsule()
                            .fill(.quaternary)
                            .frame(width: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(width: 148)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: presenter.isProWindowRequested) { _, isRequested in
            if isRequested {
                openWindow(id: "purchases")
                presenter.proWindowOpened()
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 1)
            }
            content()
        }
    }

    private func slot(_ state: ChannelStripSlotViewState) -> some View {
        ChannelStripSlotView(state: state) { action in
            Task { await presenter.handleSlot(action, at: state.id) }
        }
    }
}
