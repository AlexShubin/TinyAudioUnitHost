import ProjectDescription

let project = Project(
    name: "EngineKit",
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
            name: "EngineKit",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.EngineKit",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ],
            dependencies: [
                .project(target: "Common", path: .relativeToManifest("../Common")),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "AudioSettings", path: .relativeToManifest("../AudioSettings")),
            ]
        ),
        .target(
            name: "EngineKitTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.alexshubin.TinyAudioUnitHost.EngineKitTests",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Tests",
            ],
            dependencies: [
                .target(name: "EngineKit"),
                .project(target: "Common", path: .relativeToManifest("../Common")),
                .project(target: "CommonTestSupport", path: .relativeToManifest("../Common")),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "StorageKitTestSupport", path: .relativeToManifest("../StorageKit")),
                .project(target: "AudioSettings", path: .relativeToManifest("../AudioSettings")),
                .project(target: "AudioSettingsTestSupport", path: .relativeToManifest("../AudioSettings")),
            ]
        ),
    ]
)
