import ProjectDescription

let project = Project(
    name: "Common",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.2",
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
            name: "Common",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.Common",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ]
        ),
    ]
)
