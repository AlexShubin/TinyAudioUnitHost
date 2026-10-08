//
//  PresetNameDialogView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct PresetNameDialogView: View {
    let presenter: PresetNameDialogPresenterType
    @State private var name: String

    init(presenter: PresetNameDialogPresenterType) {
        self.presenter = presenter
        _name = State(initialValue: presenter.initialName)
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.accentColor.gradient, in: Circle())
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Preset Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .onSubmit { presenter.commit(name: name) }
                if let message = presenter.errorMessage(for: name) {
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
                Button(presenter.commitLabel) { presenter.commit(name: name) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!presenter.canCommit(name: name))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 440)
    }
}
