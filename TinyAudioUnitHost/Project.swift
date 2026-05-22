import ProjectDescription

let appVersion = "1.1"
let buildNumber = "1"

let project = Project(
    name: "TinyAudioUnitHost",
    options: .options(automaticSchemesOptions: .enabled(codeCoverageEnabled: true)),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "CODE_SIGN_STYLE": "Automatic",
            "DEVELOPMENT_TEAM": "RBNKHS73S3",
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
                "CFBundleShortVersionString": .string(appVersion),
                "CFBundleVersion": .string(buildNumber),
                "LSApplicationCategoryType": "public.app-category.music",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            buildableFolders: [
                "Sources",
                "Resources",
            ],
            entitlements: .file(path: "Resources/TinyAudioUnitHost.entitlements"),
            dependencies: [
                .project(target: "StorageKit", path: .relativeToManifest("../StorageKit")),
                .project(target: "AudioSettingsKit", path: .relativeToManifest("../AudioSettingsKit")),
                .project(target: "AudioUnitsKit", path: .relativeToManifest("../AudioUnitsKit")),
                .project(target: "EngineKit", path: .relativeToManifest("../EngineKit")),
                .project(target: "PresetKit", path: .relativeToManifest("../PresetKit")),
                .project(target: "PurchasesKit", path: .relativeToManifest("../PurchasesKit")),
            ],
            settings: .settings(
                base: [
                    "ENABLE_APP_SANDBOX": "YES",
                    "ENABLE_HARDENED_RUNTIME": "YES",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
                    "CODE_SIGN_IDENTITY": "Apple Development",
                    "PRODUCT_NAME": "Tiny Audio Unit Host",
                    "PRODUCT_MODULE_NAME": "TinyAudioUnitHost",
                    "INFOPLIST_KEY_CFBundleDisplayName": "Tiny Audio Unit Host",
                    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.music",
                    "MARKETING_VERSION": .string(appVersion),
                    "CURRENT_PROJECT_VERSION": .string(buildNumber),
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
                .project(target: "PurchasesKit", path: .relativeToManifest("../PurchasesKit")),
                .project(target: "PurchasesKitTestSupport", path: .relativeToManifest("../PurchasesKit")),
            ],
            settings: .settings(
                base: [
                    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Tiny Audio Unit Host.app/Contents/MacOS/Tiny Audio Unit Host",
                    "BUNDLE_LOADER": "$(TEST_HOST)",
                ]
            )
        ),
    ],
    schemes: [
        .scheme(
            name: "TinyAudioUnitHost",
            shared: true,
            buildAction: .buildAction(targets: ["TinyAudioUnitHost"]),
            testAction: .targets(["TinyAudioUnitHostTests"]),
            runAction: .runAction(
                options: .options(
                    storeKitConfigurationPath: .relativeToManifest("../PurchasesKit/Products.storekit")
                )
            )
        ),
    ]
)
