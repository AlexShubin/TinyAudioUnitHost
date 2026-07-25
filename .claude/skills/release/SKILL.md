---
name: release
description: App Store release flow — start a release branch with version/build bump, bump builds for re-uploads, finish by squash-merging into main and tagging. Use when starting a new release, bumping the build number, or wrapping up a released version.
---

# Release flow

A release lives on a `release/MAJOR.MINOR.PATCH` branch. The lifecycle: branch → bump immediately → do the work → user uploads/releases via Xcode → squash-merge into main → tag.

All commits and pushes in this flow follow the project's git rules: explicit per-action permission, every time.

## Versioning rules

- `appVersion` and `buildNumber` are declared once at the top of `TinyAudioUnitHost/Project.swift` and feed both the Info.plist (`CFBundleShortVersionString` / `CFBundleVersion`) and the build settings (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`). Edit them there, nowhere else.
- **`appVersion` is always three-part `MAJOR.MINOR.PATCH`** (e.g. `1.2.0`) — including the trailing `.0` for non-patch releases. This matches the git release tags (`vMAJOR.MINOR.PATCH`): a release's tag is its `appVersion` with a `v` prefix, one-to-one.
- **`buildNumber` only ever goes up — never reset it.** It must strictly increase across the app's entire lifetime. The App Store rejects any upload whose build number isn't higher than the last build it received, even when the marketing version changes. Bumping `appVersion` does **not** allow resetting `buildNumber` — every version bump also increments `buildNumber`.
- After editing `Project.swift`, run `mise run generate`.

## Starting a release

1. `git checkout main && git pull`
2. `git checkout -b release/X.Y.Z`
3. Immediately bump `appVersion` to `X.Y.Z` and increment `buildNumber` in `TinyAudioUnitHost/Project.swift`, then `mise run generate`.
4. Commit the bump (e.g. `Bump version to X.Y.Z (build N)`) and push the branch — with permission.

## During the release

- Feature/fix work happens on the branch with the normal review→test→commit cadence.
- Each new upload to App Store Connect needs a `buildNumber` increment (commit it before the user archives).

## Finishing a release

Only after the user confirms the version is released on the App Store:

1. `git checkout main && git pull`
2. `git merge --squash release/X.Y.Z`
3. Commit as `Release X.Y.Z` (single squash commit, matching `Release 1.2.0` on main).
4. `git tag vX.Y.Z`
5. `git push origin main vX.Y.Z`
6. Delete the release branch both locally and on origin — never leave it behind:
   `git branch -D release/X.Y.Z && git push origin --delete release/X.Y.Z`
