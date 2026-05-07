import ProjectDescription

let project = Project(
    name: "AudioUnitsKit",
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
            name: "AudioUnitsKit",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioUnitsKit",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ]
        ),
        .target(
            name: "AudioUnitsKitTestSupport",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioUnitsKitTestSupport",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "TestSupport",
            ],
            dependencies: [
                .target(name: "AudioUnitsKit"),
            ]
        ),
    ]
)
