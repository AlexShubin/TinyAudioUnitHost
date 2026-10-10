import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "CoreMidiGatewayKit",
    dependencies: [.module("AudioUnitsKit")],
    testSupportDependencies: [.module("AudioUnitsKit")]
)
