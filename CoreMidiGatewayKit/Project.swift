import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "CoreMidiGatewayKit",
    dependencies: [.module("AudioUnitsKit"), .module("Common")],
    testSupportDependencies: [.module("AudioUnitsKit")]
)
