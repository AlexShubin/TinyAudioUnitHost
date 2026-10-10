import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "CoreAudioGatewayKit",
    dependencies: [.module("Common")],
    testSupportDependencies: [.module("Common")]
)
