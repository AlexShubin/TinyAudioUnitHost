import ProjectDescription

let project = Project(
    name: "PurchasesKit",
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
            name: "PurchasesKit",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.PurchasesKit",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Sources",
            ],
            dependencies: []
        ),
        .target(
            name: "PurchasesKitTestSupport",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.alexshubin.TinyAudioUnitHost.PurchasesKitTestSupport",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "TestSupport",
            ],
            dependencies: [
                .target(name: "PurchasesKit"),
            ]
        ),
        .target(
            name: "PurchasesKitTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.alexshubin.TinyAudioUnitHost.PurchasesKitTests",
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [
                "Tests",
            ],
            dependencies: [
                .target(name: "PurchasesKit"),
                .target(name: "PurchasesKitTestSupport"),
            ]
        ),
    ]
)
