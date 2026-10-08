//
//  PurchasesView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct PurchasesView: View {
    let presenter: PurchasesPresenterType

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: presenter.isPro ? "star.fill" : "star")
                .font(.system(size: 48))
                .foregroundStyle(presenter.isPro ? Color.yellow : Color.secondary)
                .padding(.top, 32)

            VStack(spacing: 8) {
                Text("Tiny Audio Unit Host Pro")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Save and manage unlimited presets.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if presenter.isPro {
                Text("You're Pro.")
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else {
                buySection
            }

            if let errorMessage = presenter.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(width: 440)
    }

    @ViewBuilder
    private var buySection: some View {
        VStack(spacing: 12) {
            if let priceLabel = presenter.priceLabel {
                Text(priceLabel)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Button {
                Task { await presenter.buy() }
            } label: {
                if presenter.isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Upgrade to Pro")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(presenter.isBusy)

            Button("Restore Purchase") {
                Task { await presenter.restore() }
            }
            .buttonStyle(.borderless)
            .disabled(presenter.isBusy)
        }
    }
}
