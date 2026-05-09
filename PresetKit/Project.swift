import ProjectDescription

let project = Project(
    name: "PresetKit",
    options: .options(automaticSchemesOptions: .enabled(codeCoverageEnabled: true)),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "CODE_SIGN_STYLE": "Manual",
            "CODE_SIGN_IDENTITY": "Apple Development",
            "DEVELOPMENT_TEAM": "",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .target(
            name: "PresetKit",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.PresetKit",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ],
            dependencies: [
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "AudioUnitsKit", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "EngineKit", path: .relativeToManifest("../EngineKit")),
            ]
        ),
        .target(
            name: "PresetKitTestSupport",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.PresetKitTestSupport",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "TestSupport",
            ],
            dependencies: [
                .target(name: "PresetKit"),
                .project(target: "AudioUnitsKit", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "AudioUnitsKitTestSupport", path: .relativeToManifest("../AudioUnitsKit")),
            ]
        ),
        .target(
            name: "PresetKitTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.alexshubin.TinyAudioUnitHost.PresetKitTests",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Tests",
            ],
            dependencies: [
                .target(name: "PresetKit"),
                .target(name: "PresetKitTestSupport"),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "StorageKitTestSupport", path: .relativeToManifest("../StorageKit")),
                .project(target: "AudioUnitsKit", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "AudioUnitsKitTestSupport", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "EngineKit", path: .relativeToManifest("../EngineKit")),
                .project(target: "EngineKitTestSupport", path: .relativeToManifest("../EngineKit")),
            ]
        ),
    ]
)
