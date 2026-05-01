import ProjectDescription

let project = Project(
    name: "AudioSettings",
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
            name: "AudioSettings",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioSettings",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ],
            dependencies: [
                .project(target: "Common", path: .relativeToManifest("../Common")),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
            ]
        ),
        .target(
            name: "AudioSettingsTestSupport",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioSettingsTestSupport",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "TestSupport",
            ],
            dependencies: [
                .target(name: "AudioSettings"),
                .project(target: "Common", path: .relativeToManifest("../Common")),
                .project(target: "CommonTestSupport", path: .relativeToManifest("../Common")),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
            ]
        ),
        .target(
            name: "AudioSettingsTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.alexshubin.TinyAudioUnitHost.AudioSettingsTests",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Tests",
            ],
            dependencies: [
                .target(name: "AudioSettings"),
                .target(name: "AudioSettingsTestSupport"),
                .project(target: "Common", path: .relativeToManifest("../Common")),
                .project(target: "CommonTestSupport", path: .relativeToManifest("../Common")),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "StorageKitTestSupport", path: .relativeToManifest("../StorageKit")),
            ]
        ),
    ]
)
