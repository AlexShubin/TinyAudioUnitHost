import ProjectDescription

let project = Project(
    name: "TinyAudioUnitHost",
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
            name: "TinyAudioUnitHost",
            destinations: .macOS,
            product: .app,
            bundleId: "com.alexshubin.TinyAudioUnitHost",
            deploymentTargets: .macOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "NSMicrophoneUsageDescription": "Audio Unit hosting requires audio access.",
                "CFBundleIconName": "AppIcon",
                "CFBundleDisplayName": "Tiny Audio Unit Host",
                "CFBundleName": "Tiny Audio Unit Host",
            ]),
            buildableFolders: [
                "Sources",
                "Resources",
            ],
            dependencies: [
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "AudioSettingsKit", path: .relativeToManifest("../AudioSettingsKit")),
                .project(target: "AudioUnitsKit", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "EngineKit", path: .relativeToManifest("../EngineKit")),
                .project(target: "PresetKit", path: .relativeToManifest("../PresetKit")),
            ],
            settings: .settings(
                base: [
                    "ENABLE_APP_SANDBOX": "NO",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
                ]
            )
        ),
        .target(
            name: "TinyAudioUnitHostTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.alexshubin.TinyAudioUnitHost.TinyAudioUnitHostTests",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Tests",
            ],
            dependencies: [
                .target(name: "TinyAudioUnitHost"),
                .project(target: "AudioSettingsKit", path: .relativeToManifest("../AudioSettingsKit")),
                .project(target: "AudioSettingsKitTestSupport", path: .relativeToManifest("../AudioSettingsKit")),
                .project(target: "AudioUnitsKit", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "AudioUnitsKitTestSupport", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "EngineKit", path: .relativeToManifest("../EngineKit")),
                .project(target: "EngineKitTestSupport", path: .relativeToManifest("../EngineKit")),
                .project(target: "PresetKit", path: .relativeToManifest("../PresetKit")),
                .project(target: "PresetKitTestSupport", path: .relativeToManifest("../PresetKit")),
            ]
        ),
    ]
)
