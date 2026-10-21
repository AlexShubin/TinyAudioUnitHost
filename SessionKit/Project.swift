import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "SessionKit",
    dependencies: [
        .module("AudioToolboxGatewayKit"),
        .module("Common"),
        .module("CoreMidiGatewayKit"),
        .module("AudioUnitsKit"),
        .module("PresetKit"),
    ],
    testSupportDependencies: [
        .module("AudioUnitsKit"),
    ],
    tests: [
        .module("AudioToolboxGatewayKit"),
        .testSupport("AudioToolboxGatewayKit"),
        .module("CoreMidiGatewayKit"),
        .testSupport("CoreMidiGatewayKit"),
        .module("Common"),
        .testSupport("Common"),
        .module("AudioUnitsKit"),
        .testSupport("AudioUnitsKit"),
        .module("PresetKit"),
        .testSupport("PresetKit"),
    ]
)
