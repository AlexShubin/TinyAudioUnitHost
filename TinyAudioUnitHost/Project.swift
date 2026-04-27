import ProjectDescription

let project = Project(
    name: "TinyAudioUnitHost",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
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
            ]),
            buildableFolders: [
                "Sources",
                "Resources",
            ],
            dependencies: [
                .project(target: "Common", path: .relativeToManifest("../Common")),
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
            ],
            settings: .settings(
                base: [
                    "ENABLE_APP_SANDBOX": "NO",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
                ]
            )
        ),
    ]
)
