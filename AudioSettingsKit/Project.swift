import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "AudioSettingsKit",
    dependencies: [
        .module("Common"),
        .module("CoreAudioGatewayKit"),
        .module("CoreMidiGatewayKit"),
        .module("StorageKit"),
    ],
    testSupportDependencies: [
        .module("StorageKit"),
    ],
    tests: [
        .module("CoreAudioGatewayKit"),
        .testSupport("CoreAudioGatewayKit"),
        .module("CoreMidiGatewayKit"),
        .testSupport("CoreMidiGatewayKit"),
        .module("StorageKit"),
        .testSupport("StorageKit"),
    ]
)
