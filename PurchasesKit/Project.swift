import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.library(
    name: "PurchasesKit",
    dependencies: [.module("Common")],
    tests: []
)
