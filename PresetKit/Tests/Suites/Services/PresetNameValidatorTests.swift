//
//  PresetNameValidatorTests.swift
//  PresetKitTests
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit
import StorageKitTestSupport
import Testing
@testable import PresetKit

@Suite
struct PresetNameValidatorTests {
    var rawStoreMock: RawPresetStoreMock!
    var sut: PresetNameValidatorType!

    init() {
        rawStoreMock = RawPresetStoreMock()
    }

    mutating func createSut() {
        sut = PresetNameValidator(rawStore: rawStoreMock)
    }

    // MARK: - basic rules

    @Test
    mutating func validName_returnsNil() {
        createSut()

        #expect(sut.validate(name: "MyPreset", for: .saveAs) == nil)
    }

    @Test
    mutating func empty_returnsEmpty() {
        createSut()

        #expect(sut.validate(name: "", for: .saveAs) == .empty)
    }

    @Test
    mutating func whitespaceOnly_returnsEmpty() {
        createSut()

        #expect(sut.validate(name: "   ", for: .saveAs) == .empty)
    }

    @Test
    mutating func trimsLeadingTrailingWhitespace() {
        createSut()

        #expect(sut.validate(name: "  MyPreset  ", for: .saveAs) == nil)
    }

    @Test
    mutating func containsSlash_returnsInvalidCharacter() {
        createSut()

        #expect(sut.validate(name: "Bad/Name", for: .saveAs) == .invalidCharacter)
    }

    @Test
    mutating func containsColon_returnsInvalidCharacter() {
        createSut()

        #expect(sut.validate(name: "Bad:Name", for: .saveAs) == .invalidCharacter)
    }

    @Test
    mutating func leadingDot_returnsInvalidCharacter() {
        createSut()

        #expect(sut.validate(name: ".hidden", for: .saveAs) == .invalidCharacter)
    }

    // MARK: - saveAs mode

    @Test
    mutating func saveAs_uniqueName_returnsNil() {
        rawStoreMock.presets = ["alpha": .fake(), "bravo": .fake()]
        createSut()

        #expect(sut.validate(name: "charlie", for: .saveAs) == nil)
    }

    @Test
    mutating func saveAs_duplicate_returnsDuplicate() {
        rawStoreMock.presets = ["existing": .fake()]
        createSut()

        #expect(sut.validate(name: "existing", for: .saveAs) == .duplicate)
    }

    @Test
    mutating func saveAs_duplicateCaseInsensitive_returnsDuplicate() {
        rawStoreMock.presets = ["Existing": .fake()]
        createSut()

        #expect(sut.validate(name: "EXISTING", for: .saveAs) == .duplicate)
    }

    // MARK: - rename mode

    @Test
    mutating func rename_sameAsCurrent_returnsNil() {
        rawStoreMock.presets = ["Foo": .fake(), "Bar": .fake()]
        createSut()

        #expect(sut.validate(name: "Foo", for: .rename(currentName: "Foo")) == nil)
    }

    @Test
    mutating func rename_otherDuplicate_returnsDuplicate() {
        rawStoreMock.presets = ["Foo": .fake(), "Bar": .fake()]
        createSut()

        #expect(sut.validate(name: "Bar", for: .rename(currentName: "Foo")) == .duplicate)
    }

    @Test
    mutating func rename_uniqueName_returnsNil() {
        rawStoreMock.presets = ["Foo": .fake()]
        createSut()

        #expect(sut.validate(name: "Baz", for: .rename(currentName: "Foo")) == nil)
    }
}
