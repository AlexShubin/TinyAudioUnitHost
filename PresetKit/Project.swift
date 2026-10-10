import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "PresetKit",
    dependencies: [
        .module("StorageKit"),
        .module("AudioUnitsKit"),
    ],
    testSupportDependencies: [
        .module("AudioUnitsKit"),
        .testSupport("AudioUnitsKit"),
    ],
    tests: [
        .module("StorageKit"),
        .testSupport("StorageKit"),
        .module("AudioUnitsKit"),
        .testSupport("AudioUnitsKit"),
    ]
)
