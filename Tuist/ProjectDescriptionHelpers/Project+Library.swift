import ProjectDescription

public extension Project {
    static func library(
        name: String,
        dependencies: [TargetDependency] = [],
        testSupportDependencies: [TargetDependency] = [],
        tests: [TargetDependency]? = nil
    ) -> Project {
        var targets: [Target] = [
            .framework(name, folder: "Sources", dependencies: dependencies),
            .framework(
                "\(name)TestSupport",
                folder: "TestSupport",
                dependencies: [.target(name: name)] + testSupportDependencies
            ),
        ]
        if let tests {
            targets.append(.target(
                name: "\(name)Tests",
                destinations: .macOS,
                product: .unitTests,
                bundleId: bundleIdentifier(for: "\(name)Tests"),
                deploymentTargets: .macOS("26.0"),
                buildableFolders: ["Tests"],
                dependencies: [.target(name: name), .target(name: "\(name)TestSupport")] + tests
            ))
        }
        return Project(
            name: name,
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
            targets: targets
        )
    }
}

public extension TargetDependency {
    static func module(_ name: String) -> TargetDependency {
        .project(target: name, path: .relativeToManifest("../\(name)"))
    }

    static func testSupport(_ name: String) -> TargetDependency {
        .project(target: "\(name)TestSupport", path: .relativeToManifest("../\(name)"))
    }
}

private extension Target {
    static func framework(_ name: String, folder: String, dependencies: [TargetDependency]) -> Target {
        .target(
            name: name,
            destinations: .macOS,
            product: .staticFramework,
            bundleId: bundleIdentifier(for: name),
            deploymentTargets: .macOS("26.0"),
            buildableFolders: [.init(stringLiteral: folder)],
            dependencies: dependencies
        )
    }
}

private func bundleIdentifier(for target: String) -> String {
    "com.alexshubin.TinyAudioUnitHost.\(target)"
}
