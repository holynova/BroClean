# Architecture

BroClean uses Swift 6, SwiftUI and an AppKit NSStatusItem/NSPanel shell. The dependency-free Swift package builds using macOS Command Line Tools. `scripts/build-app.sh` produces an ad-hoc signed local .app; it is not a notarized distribution.

## Components

- CProcess: small libproc/sysctl shim. Reads BSD identity, resident memory, argv, process-owned TCP listeners. It never sends signals.
- BrowserScopeCore: immutable process snapshots, browser resolver, source/profile evidence, bulk policy, identity-checked signal gateway, termination coordinator and CDP page reader.
- BrowserScopeApp: NSStatusItem anchors a borderless, key-capable NSPanel hosting SwiftUI. UI state on MainActor; scans explicitly dispatched off the main thread. Page probing is separate from basic process discovery. App-specific graceful quit uses NSRunningApplication.
- BrowserScopeDiagnostics: read-only JSON scan plus bounded validation helpers for disposable test processes. No generic cleanup command.

## Identity and uncertainty

PID + kernel start-time microseconds identify processes. macOS code-sign clones retain the live kernel executable path for identity checks, while the kernel-recorded original launch path identifies the browser bundle for child grouping. Revalidation lowers but does not eliminate the check-to-signal race. All protected ancestors and PID <=1 are excluded. A mode, framework and inferred source are separate facts. RSS sum is estimated and may double-count shared pages. Safari XPC ownership is incomplete and marked partial. Unknown CDP data is distinct from known zero pages.

## Lifecycle

App opens -> status item -> background snapshot -> browser roots + descendants -> display. Popover open: 2s between refresh cycles; closed: 10s. Scanning and endpoint request time is additional. Sleep suspends polling; wake refreshes. No overlapping scans. Short-lived processes may be missed between samples. Browser list identity remains stable across refreshes; no automatic resort by fluctuating memory while interacting.

Close actions freeze instances, revalidate, request graceful quit or TERM, then rescan. Explicit Force quit only targets revalidated tree members. Does not terminate launcher ancestors or delete profiles. Return per-instance results and correlate suspected restarts only using a unique temporary profile. Session-level launcher shutdown is deferred.

## CDP

Read the browser's remote-debugging-port argument or DevToolsActivePort in its nonstandard profile. Require a listening TCP socket owned by the same root process, loopback HTTP only; do not scan arbitrary ports. GET /json/list with timeout and no redirect; count top-level page targets except extension/devtools pages. Pipe-only returns unknown. This MVP uses the listing endpoint rather than attaching a debugger or executing JS. HTTP failures do not block scanning or closing.

## Persistence and permissions

UserDefaults: selected filter. SMAppService owns login registration state. Per-instance protection is stored by InstanceProtectionStore, shared by desktop and CLI, keyed by process identity. No raw command logs, browsing data, database, network upload or privileged service. Login item uses SMAppService. Real browser icons come from the installed app bundle via NSWorkspace; SF Symbols cover controls and missing app icons.

## Compact panel revision

The panel is 400pt wide with a 268pt list viewport (about 70% of the original dimensions). Layout metrics and fonts are adjusted individually rather than applying a bitmap scale. Each row exposes a Close button; force quit and protection remain in the overflow menu. Only the identity text toggles details, so row gestures do not intercept action buttons.

The panel is application-managed and does not hide on deactivation. A global mouse monitor dismisses it for external clicks; internal menus and confirmation sheets stay within the application. Pending confirmation and active cleanup suppress outside dismissal. Status-item clicks toggle the panel. Monitor lifetime follows panel visibility. Screen-bound clamping prevents invalid/overflowed status-item anchors from placing the panel offscreen. Reopening the app shows a hidden panel.

A headed standard-profile instance with no automation, debugging or known source evidence is displayed using its browser name and Personal browser. Details explicitly describe this as likely personal use. Unknown or automated instances do not receive this presentation fallback.

## Sorting and automated cleanup

BrowserSorter provides name, mode/type, browser family, RSS bytes, pages, PID and age ordering. Missing memory/pages always sort last, and identity resolves ties deterministically. The app persists key/direction and applies ordering after each tab filter. Column clicks reverse direction; additional keys and explicit direction are in the sorting menu.

BulkCloseScope distinguishes headless from automated. The latter also admits headed automation while retaining profile, protection, UID and identity guards. The same scope is passed through confirmation to the coordinator and used when re-resolving immediately before termination.

GitHub opens the saved repository URL. Without one, it opens a configuration sheet accepting HTTPS github.com owner/repository links. The version comes from bundle metadata. The bundle ID remains local.browserscope.app for preference continuity; the user-visible product is BroClean.

## CLI and protection persistence

BroCleanCLIKit parses options and produces close plans without side effects. BroCleanCLI formats tables/schema-versioned JSON, gates interactive actions, and uses the same TerminationCoordinator as the app. Bulk protection is rechecked at execution time through InstanceProtectionStore, not trusted solely from a CLI plan. Protection writes use flock plus atomic replacement; unreadable state fails closed for bulk cleanup.

The desktop SwiftPM executable product is BroCleanDesktop and is packaged as BroClean.app/Contents/MacOS/BroClean. The CLI product is broclean. Distinct product names are necessary because the default macOS filesystem is case-insensitive; products differing only in letter case collide in SwiftPM output and link-file lists.
