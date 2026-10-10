import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "EngineKit",
    dependencies: [
        .module("AudioToolboxGatewayKit"),
        .module("Common"),
        .module("CoreMidiGatewayKit"),
        .module("StorageKit"),
        .module("AudioSettingsKit"),
        .module("AudioUnitsKit"),
    ],
    testSupportDependencies: [
        .module("AudioSettingsKit"),
        .module("AudioUnitsKit"),
    ],
    tests: [
        .module("AudioToolboxGatewayKit"),
        .testSupport("AudioToolboxGatewayKit"),
        .module("CoreMidiGatewayKit"),
        .testSupport("CoreMidiGatewayKit"),
        .module("Common"),
        .testSupport("Common"),
        .module("StorageKit"),
        .testSupport("StorageKit"),
        .module("AudioSettingsKit"),
        .testSupport("AudioSettingsKit"),
        .module("AudioUnitsKit"),
        .testSupport("AudioUnitsKit"),
    ]
)
