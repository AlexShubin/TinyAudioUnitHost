import ProjectDescription

let project = Project(
    name: "StorageKit",
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
            name: "StorageKit",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.StorageKit",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ],
            dependencies: [
                .project(target: "Common", path: .relativeToManifest("../Common")),
            ]
        ),
    ]
)
