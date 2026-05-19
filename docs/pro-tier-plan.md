# Pro Tier — Plan

## Goal

Add a paid Pro upgrade. Free users see and save up to 2 presets; Pro users have unlimited. The cap and the upgrade flow ship together in one release.

One non-consumable in-app purchase. StoreKit 2 only (deployment is macOS 26.0).

## Scope

In:
- New module **PurchasesKit**: a thin StoreKit 2 wrapper exposing the `isPro` entitlement, `purchase()`, and `restore()`.
- One non-consumable IAP, product ID `com.alexshubin.TinyAudioUnitHost.pro`.
- A **Pro window** — its own SwiftUI `Window` scene (analogous to `Settings`), with `PurchasesView` + `PurchasesViewModel`. Buy / Restore buttons, copy describing what Pro unlocks. No app-drawn Done button — the user dismisses via the system window chrome.
- A toolbar **Pro button** in HostView that opens the window via `openWindow(id:)`.
- Gating: when a free user with 2 presets taps `+`, HostView opens the Pro window instead of the New Preset dialog. After a successful purchase the window stays open showing "You're Pro"; the user re-taps `+` themselves.
- VM-level visibility cap: `HostViewModel.presets` is sliced to `prefix(2)` when not Pro. Pre-existing presets beyond 2 are hidden until the user upgrades.
- `Products.storekit` configuration file for local development.

Out:
- Subscriptions, Family Sharing, promotional offers, redeem codes.
- Server-side receipt validation.
- Per-feature gating beyond preset count.
- Auto-resuming the New Preset dialog after a gated purchase.
- A "Done" button in the Pro window.
- "Locked" UI for hidden presets (we just hide them).

## Decisions

1. **Module name: `PurchasesKit`.**
2. **IAP type: non-consumable.** Single permanent upgrade. No expiration, no renewals, no grace periods.
3. **StoreKit 2 only.** `Transaction.currentEntitlements` is the source of truth. `Transaction.updates` delivers changes. No `SKPaymentQueue`, no receipts to ship to a server.
4. **Trust StoreKit each launch.** No `UserDefaults` cache of `isPro` — the live state is fast and authoritative.
5. **Free user with > 2 presets on disk: hide extras at the VM.** HostViewModel reads the full list from `PresetProvider`, then exposes `presets` sliced to `prefix(2)` when not Pro. The hidden files stay on disk; upgrading reveals them again.
6. **PresetProvider stays untouched.** No `isPro` parameter. No closure. The provider remains the honest data layer; the cap is a presentation rule that lives in the consumer (HostViewModel).
7. **Pro window is its own scene.** `Window("Pro", id: "purchases") { PurchasesView(...) }` declared at the App level, just like `Settings`. Opened via `@Environment(\.openWindow)` on the `id`. No Done button — the user closes the window like Settings.
8. **No entitlement update stream.** Service exposes `isPro` as an async getter; consumers re-read at meaningful moments (`task`, before the `+` gate, after a `purchase()` / `restore()` returns). Out-of-band changes (refunds, App Store promos) won't propagate until the next refresh or app restart — accepted as a v1 trade-off given how rare those are.
9. **No auto-resume on purchase.** A successful purchase leaves the user in the Pro window. To create the preset they tried to create, they close the window and tap `+` again. Simpler and removes a cross-scene coupling.
10. **Pro button stays visible when already Pro.** Tapping it opens the same window, which renders "You're Pro" + Restore. Gives Pro users a way to check status / restore on a fresh device.
11. **`+` gating semantics.** Even at 0 or 1 presets, the gate just checks `viewModel.presets.count >= 2 && !viewModel.isPro`. Free users *creating* their first or second preset go through the normal dialog. Free user attempting the 3rd save sees the Pro window.
12. **No active-preset reconciliation.** We assume "a free user cannot have more than 2 presets on disk" is invariant (enforced by the gate in `.newPresetTapped`). If the invariant somehow breaks — out-of-band entitlement loss (Apple refund) or manual file edits — the active name may point at a hidden preset and the engine will keep playing it; we don't auto-clear. Trade-off accepted alongside the earlier "no entitlement stream" decision.

## Architecture

### PurchasesKit (new module)

Public surface:

```swift
public protocol PurchasesServiceType: Sendable {
    var isPro: Bool { get async }
    var productInfo: ProProductInfo? { get async }
    func purchase() async -> PurchaseResult
    func restore() async -> PurchaseResult
}

public struct ProProductInfo: Sendable, Equatable {
    public let displayName: String
    public let description: String
    public let displayPrice: String        // StoreKit-formatted
}

public enum PurchaseResult: Sendable, Equatable {
    case success
    case userCancelled
    case pending              // ask-to-buy
    case productUnavailable
    case verificationFailed
    case unknownError(String)
}
```

Concrete `PurchasesService` (`internal actor`):
- Loads the Pro product lazily on first access (`Product.products(for: [Self.proID])`).
- `isPro`: iterates `Transaction.currentEntitlements`, returns `true` if any verified entitlement matches the Pro product ID.
- Long-running `Task<Void, Never>` consuming `Transaction.updates` — it just calls `transaction.finish()` on verified updates so out-of-band transactions (promo purchases, ask-to-buy approvals) get acknowledged. No broadcast.
- `purchase()`: fetches product, calls `product.purchase()`, maps the StoreKit result, finishes the transaction on success.
- `restore()`: `try? await AppStore.sync()`; callers re-read `isPro` afterwards.

No reactive entitlements stream. Consumers re-read `isPro` at the moments they care about — initial `task`, just before the `+` gate decision, after a `purchase()` / `restore()` call returns. Out-of-band entitlement changes (refunds, promos) won't propagate until the next such moment or app restart, which is acceptable for v1.

`PurchasesKit.Dependencies.live` wires the service. `PurchasesServiceMock` lives in `PurchasesKit/TestSupport/Mocks/`.

### PresetKit

**Unchanged.** No new dependencies, no parameter changes, no behavior changes.

### App layer — HostViewModel

New state:
- `isPro: Bool` — observed, starts false. Read from the service at meaningful moments (see below).

`presets` becomes a computed property that slices on read:

```swift
private(set) var allPresets: [Preset] = []
var presets: [Preset] { isPro ? allPresets : Array(allPresets.prefix(2)) }
```

`allPresets` is the raw cache from the provider; `presets` (the public surface) slices to `prefix(2)` whenever the user isn't Pro. Slicing on read means any reader always sees the current `isPro` without manual re-slicing. We assume the invariant *"a free user cannot have more than 2 presets on disk"* holds (enforced by the gate in `.newPresetTapped`), so we don't reconcile active when the slice changes — a free user with > 2 on disk is treated as out of scope.

```swift
private(set) var allPresets: [Preset] = []
var presets: [Preset] { isPro ? allPresets : Array(allPresets.prefix(2)) }
```

(`presets` stays a `var` so existing consumers and tests keep working unchanged; `allPresets` is the raw cache.)

Every place that used to write `presets = presetProvider.presets` becomes `allPresets = presetProvider.presets`. No reconciliation — see decision #12.

Init takes the new dependency:

```swift
init(
    library: AudioUnitComponentsLibraryType,
    engine: EngineType,
    presetProvider: PresetProviderType,
    setupChecker: SetupCheckerType,
    presetNameValidator: PresetNameValidatorType,
    purchasesService: PurchasesServiceType
)
```

Refresh moments for `isPro`:
- `task` action — initial async read.
- `.newPresetTapped` action — re-read before deciding whether to gate. This is the user's primary engagement point with Pro state, so we treat it as the refresh trigger.

```swift
case .task:
    // ... existing setup
    isPro = await purchasesService.isPro
    allPresets = presetProvider.presets

case .newPresetTapped:
    isPro = await purchasesService.isPro
    allPresets = presetProvider.presets
    if !isPro && presets.count >= 2 {
        openProWindowRequest = UUID()
    } else {
        newPresetDialog = NewPresetDialogState(name: "", error: nil)
    }
```

`openProWindowRequest: UUID?` is a one-shot token: the View observes it via `onChange` and calls `openWindow(id: "purchases")` when it goes non-nil. A fresh `UUID()` per request so SwiftUI's diffing actually fires for the second tap.

The toolbar Pro button still uses `openWindow` directly (no async refresh) — its appearance might briefly be stale until the next `task` / `+ tap`, which is fine: clicking it always shows the correct state inside the Pro window.

### App layer — PurchasesViewModel (new)

Same shape as `SettingsViewModel`. Lives in `TinyAudioUnitHost/Sources/Features/Pro/` (mirror the existing `Features/Settings/` directory layout).

```swift
@MainActor
protocol PurchasesViewModelType: AnyObject, Observable {
    var isPro: Bool { get }
    var productInfo: ProProductInfo? { get }
    var phase: PurchasesPhase { get }
    var errorMessage: String? { get }
    func accept(action: PurchasesViewModelAction) async
}

enum PurchasesPhase: Sendable, Equatable {
    case idle
    case purchasing
    case restoring
}

enum PurchasesViewModelAction: Sendable, Equatable {
    case task
    case buyTapped
    case restoreTapped
}
```

`task`: reads initial `isPro` and `productInfo` from the service.

`buyTapped`:
- `phase = .purchasing`, `errorMessage = nil`.
- `let result = await purchasesService.purchase()`.
- `phase = .idle`. Re-read `isPro = await purchasesService.isPro` so the view flips to "You're Pro" on success.
- `.success`: nothing else.
- `.userCancelled` / `.pending`: no error message.
- Other cases: `errorMessage = humanReadableError(result)`.

`restoreTapped`: same shape with `purchasesService.restore()`.

No listener. After every action that might have changed entitlement, we re-read explicitly.

### App layer — PurchasesView

`Features/Pro/PurchasesView.swift`:

Layout (rough):
- Title: "Tiny Audio Unit Host Pro"
- Subtitle: "Unlimited presets — save every patch you build"
- Price line: `viewModel.productInfo?.displayPrice` (placeholder while loading)
- Buy button: "Upgrade to Pro" — visible only when `!isPro`. `.disabled(viewModel.phase == .purchasing)`. Loading spinner when phase == .purchasing.
- Restore button: "Restore Purchase". `.disabled(viewModel.phase == .restoring)`. Loading spinner when phase == .restoring.
- "You're Pro" message — visible only when `isPro`.
- Inline error area — only when `errorMessage != nil`.
- No Done button. The user closes the window via the title-bar close button.

`task { await viewModel.accept(action: .task) }` on the View.

### App layer — Window scene

In `TinyAudioUnitHostApp`:

```swift
Window("Tiny Audio Unit Host Pro", id: "purchases") {
    withTestsDisabled { PurchasesView(viewModel: dependencies.makePurchasesViewModel()) }
}
.windowResizability(.contentSize)
```

`dependencies.makePurchasesViewModel()` is a new factory analogous to `makeSettingsViewModel`.

### App layer — HostView

Toolbar gains the Pro button right of `+`, before the existing `Spacer()`. The button uses `@Environment(\.openWindow)`:

```swift
@Environment(\.openWindow) private var openWindow

// in toolbar:
Button {
    openWindow(id: "purchases")
} label: {
    Image(systemName: viewModel.isPro ? "star.fill" : "star")
}
.help(viewModel.isPro ? "Pro features" : "Upgrade to Pro")
```

The `+` button gate also intercepts at the View:

```swift
Button {
    if !viewModel.isPro && viewModel.presets.count >= 2 {
        openWindow(id: "purchases")
    } else {
        Task { await viewModel.accept(action: .newPresetTapped) }
    }
} label: {
    Image(systemName: "plus")
}
.help("Save as new preset")
.disabled(!viewModel.content.isLoaded)
```

The gate logic is two-line, mirrors the disabled / hidden conditions already in the toolbar, and keeps `openWindow` (a View concern) out of the VM.

### StoreKit configuration

`TinyAudioUnitHost/Resources/Products.storekit`:
- Non-consumable product `com.alexshubin.TinyAudioUnitHost.pro`
- Display name, description, price tier (test).

Scheme settings → Run → Options → "StoreKit Configuration": select the file. Local Xcode runs against the simulated store; useful for development + UI screenshots.

Sandbox testing (TestFlight + sandbox testers): leave the scheme without the file; the app talks to real StoreKit in sandbox mode for testers signed in via Settings → App Store → Sandbox Account.

## Steps

1. **PurchasesKit module.** New project, `Sources/`, `TestSupport/`, `Tests/`. Add to `Workspace.swift`. Protocol + concrete service + mock. Unit tests using `SKTestSession`. (`mise run generate` runs here.)
2. **HostViewModel**: add `isPro`, `allPresets`, the `task` initial read of `isPro`, the `.newPresetTapped` async refresh + gate via `openProWindowRequest`. Update existing call sites that write to `presets` to write to `allPresets`. Update HostViewModelTests.
3. **PurchasesViewModel + PurchasesView**: new files under `Features/Pro/`.
4. **Window scene**: declare in `TinyAudioUnitHostApp`. Composition root adds `makePurchasesViewModel`.
5. **HostView**: toolbar Pro button + View-side `+` gate, both using `openWindow(id: "purchases")`.
6. **`Products.storekit`** + scheme StoreKit Configuration setting.
7. **Manual QA inside Xcode** with the StoreKit config: buy, ask-to-buy, cancel, restore, refund (Edit → Manage Transactions → revoke), and verify the entitlement listener correctly updates while the Pro window is open.
8. **App Store Connect setup** (manual, outside the codebase): agreements, banking, tax; create the non-consumable IAP; submit for review with the app.
9. **Sandbox testing** with a TestFlight build.

## Test plan

- `PurchasesServiceTests` with `SKTestSession`: purchase happy path, cancel, restore, verification failure, entitlement-stream basic behavior.
- `PurchasesViewModelTests`: each phase transition; phase resets after success / cancel / error; error mapped from `PurchaseResult`.
- `HostViewModelTests`: extend `task` to cover `isPro` initial read; `presets` slice (free vs Pro); `.newPresetTapped` gate at the cap; below the cap; Pro above the cap; repeated taps generating fresh `openProWindowRequest` tokens.

## Open questions (decide later, low-stakes)

- Pricing in App Store Connect — you pick, the code just reads `displayPrice`.
- Toolbar Pro icon — `star` / `star.fill` (yellow when Pro).
- Copy in the Pro window — placeholder strings for now; tune before App Review.
- Whether the Pro window should be resizable or fixed-size. Defaulting to `.windowResizability(.contentSize)` (fixed to content) to match Settings.

## Notes on conventions

- New module follows the standard layout: `Sources/Services/`, `Sources/Models/` (for `ProProductInfo`, `PurchaseResult`), `TestSupport/Mocks/`, `Tests/Suites/`.
- Concrete `PurchasesService` stays `internal` behind the `PurchasesServiceType` protocol.
- `PurchasesService` is an `actor` — owns mutable state (cached product reference + the long-running `Transaction.updates` consumer). That's an honest use of `actor`.
- `PurchasesViewModel` lives in `Features/Pro/` to mirror `Features/Settings/`.
- The View, not the VM, calls `openWindow` — windowing is presentation, not VM business logic.
