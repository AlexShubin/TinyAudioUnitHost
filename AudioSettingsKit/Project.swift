import ProjectDescription

let project = Project(
    name: "AudioSettingsKit",
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
            name: "AudioSettingsKit",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioSettingsKit",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ],
            dependencies: [
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
            ]
        ),
        .target(
            name: "AudioSettingsKitTestSupport",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioSettingsKitTestSupport",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "TestSupport",
            ],
            dependencies: [
                .target(name: "AudioSettingsKit"),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
            ]
        ),
        .target(
            name: "AudioSettingsKitTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioSettingsKitTests",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Tests",
            ],
            dependencies: [
                .target(name: "AudioSettingsKit"),
                .target(name: "AudioSettingsKitTestSupport"),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "StorageKitTestSupport", path: .relativeToManifest("../StorageKit")),
            ]
        ),
    ]
)
