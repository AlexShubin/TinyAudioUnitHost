//
//  PresetNameDialogView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct PresetNameDialogView: View {
    @State var presenter: PresetNameDialogPresenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.accentColor.gradient, in: Circle())
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Preset Name", text: $presenter.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .onSubmit { presenter.commit() }
                if let message = presenter.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)

            HStack {
                Button("Cancel", role: .cancel) { presenter.cancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(presenter.commitLabel) { presenter.commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!presenter.canCommit)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 440)
        .onChange(of: presenter.isDismissed) { _, isDismissed in
            if isDismissed { dismiss() }
        }
    }
}
