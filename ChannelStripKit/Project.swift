import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "ChannelStripKit",
    dependencies: [
        .module("AudioToolboxGatewayKit"),
        .module("Common"),
        .module("CoreMidiGatewayKit"),
        .module("AudioUnitsKit"),
    ],
    testSupportDependencies: [
        .module("AudioUnitsKit"),
        .testSupport("AudioUnitsKit"),
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
    ]
)
