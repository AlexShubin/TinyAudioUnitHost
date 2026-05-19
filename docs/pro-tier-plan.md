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
8. **The window self-updates on entitlement change.** While open, if `entitlementUpdates` fires `true`, the window flips from buy-state to "You're Pro". No need for `pendingNewPresetAfterUpgrade` or any cross-window coordination.
9. **No auto-resume on purchase.** A successful purchase leaves the user in the Pro window. To create the preset they tried to create, they close the window and tap `+` again. Simpler and removes a cross-scene coupling.
10. **Pro button stays visible when already Pro.** Tapping it opens the same window, which renders "You're Pro" + Restore. Gives Pro users a way to check status / restore on a fresh device.
11. **`+` gating semantics.** Even at 0 or 1 presets, the gate just checks `viewModel.presets.count >= 2 && !viewModel.isPro`. Free users *creating* their first or second preset go through the normal dialog. Free user attempting the 3rd save sees the Pro window.
12. **Active preset reconciliation on downgrade.** When the entitlement listener flips to false and the active preset name no longer appears in the (newly sliced) visible list, the VM clears active via `setActive(nil)` — same code path that already handles a stale active name. Engine state is left as-is (consistent with the earlier "not selected" decision).

## Architecture

### PurchasesKit (new module)

Public surface:

```swift
public protocol PurchasesServiceType: Sendable {
    var isPro: Bool { get async }
    var entitlementUpdates: AsyncStream<Bool> { get }
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
- `entitlementUpdates`: an `AsyncStream<Bool>` fed by a long-running `Task<Void, Never>` consuming `Transaction.updates`. For each update: verify, `transaction.finish()`, re-read entitlements, yield the current value.
- `purchase()`: fetches product, calls `product.purchase()`, maps the StoreKit result, finishes the transaction on success.
- `restore()`: `try? await AppStore.sync()`, then re-reads entitlements.

`PurchasesKit.Dependencies.live` wires the service. `PurchasesServiceMock` lives in `PurchasesKit/TestSupport/Mocks/`.

### PresetKit

**Unchanged.** No new dependencies, no parameter changes, no behavior changes.

### App layer — HostViewModel

New state:
- `isPro: Bool` — observed, starts false.
- `purchasesListener: Task<Void, Never>?` — long-running, mirrors `entitlementUpdates`.

`presets` becomes a sliced view of the provider's list:

```swift
private(set) var allPresets: [Preset] = []
var presets: [Preset] { isPro ? allPresets : Array(allPresets.prefix(2)) }
```

(`presets` stays a `var` so existing consumers and tests keep working unchanged; `allPresets` is the raw cache.)

Every place that used to write `presets = presetProvider.presets` becomes:

```swift
allPresets = presetProvider.presets
reconcileActiveIfHidden()
```

`reconcileActiveIfHidden()` is the one-stop "active name should still be in the visible list" check:

```swift
private func reconcileActiveIfHidden() {
    guard let activeName, !presets.contains(where: { $0.name == activeName }) else { return }
    presetProvider.setActive(nil)
    self.activeName = nil
    // Engine state is intentionally left untouched (drift is fine; user re-saves or upgrades).
}
```

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

Listener (matches the existing setupListener shape):
```swift
purchasesListener = Task { [weak self, purchasesService] in
    for await isPro in purchasesService.entitlementUpdates {
        self?.handle(entitlementChange: isPro)
    }
}

private func handle(entitlementChange isPro: Bool) {
    self.isPro = isPro
    reconcileActiveIfHidden()
}
```

(`task` action also kicks off an initial `await purchasesService.isPro` read so the @Observable starts coherent.)

Gate inside `newPresetTapped` stays the same flow — but now the View also makes the same check before dispatching, because the View is the one who actually opens the Pro window:

```swift
case .newPresetTapped:
    guard case .loaded = content else { return }
    newPresetDialog = NewPresetDialogState(name: "", error: nil)
    // No paywall handling here — the View intercepts before this action fires.
```

(The VM doesn't open windows. Putting the gate in the View is honest: it's a presentation rule about which sheet/window to bring up.)

No new VM actions for the paywall — the Pro window is its own scene with its own VM.

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

`task`:
- Reads initial `isPro` and `productInfo` from the service.
- Spawns a listener consuming `entitlementUpdates` to keep `isPro` reactive while the window is open.

`buyTapped`:
- `phase = .purchasing`, errorMessage = nil.
- `let result = await purchasesService.purchase()`.
- `.success`: nothing else to do — the entitlement listener will flip `isPro` to true and the view re-renders. `phase = .idle`.
- `.userCancelled` or `.pending`: `phase = .idle`.
- Other cases: `phase = .idle`, `errorMessage = humanReadableError(result)`.

`restoreTapped`: same shape with `purchasesService.restore()`.

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
    Image(systemName: viewModel.isPro ? "crown.fill" : "crown")
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
2. **HostViewModel**: add `isPro`, `allPresets`, the listener, `reconcileActiveIfHidden`, the `task` initial read. Update existing call sites that write to `presets` to write to `allPresets` and follow up with the reconcile call. Update HostViewModelTests.
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
- `HostViewModelTests`: extend `task` and the "+ gate is no longer in VM" coverage; add `isPro` listener tests (initial read, stream-driven changes); reconcile-active-on-downgrade test; `presets` cap (free vs Pro).

## Open questions (decide later, low-stakes)

- Pricing in App Store Connect — you pick, the code just reads `displayPrice`.
- Toolbar Pro icon — `crown` / `crown.fill` is the default; `star.fill` / `lock.open.fill` are alternatives.
- Copy in the Pro window — placeholder strings for now; tune before App Review.
- Whether the Pro window should be resizable or fixed-size. Defaulting to `.windowResizability(.contentSize)` (fixed to content) to match Settings.

## Notes on conventions

- New module follows the standard layout: `Sources/Services/`, `Sources/Models/` (for `ProProductInfo`, `PurchaseResult`), `TestSupport/Mocks/`, `Tests/Suites/`.
- Concrete `PurchasesService` stays `internal` behind the `PurchasesServiceType` protocol.
- `PurchasesService` is an `actor` — owns mutable state (cached product reference + the long-running `Transaction.updates` consumer). That's an honest use of `actor`.
- `PurchasesViewModel` lives in `Features/Pro/` to mirror `Features/Settings/`.
- The View, not the VM, calls `openWindow` — windowing is presentation, not VM business logic.
