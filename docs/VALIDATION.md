# Validation — 2026-09-09

## Environment and delivery

- Local Apple Silicon Mac; macOS 15.1; Apple Swift 6.0.3 / Command Line Tools.
- Native SwiftUI + AppKit application. macOS 14 minimum deployment target; no third-party runtime packages.
- `swift test --disable-xctest`: **18 tests passed**. Swift Testing is used because this host has Command Line Tools but no complete XCTest framework.
- `scripts/build-app.sh`: release build, .app packaging, ad-hoc signing and strict signature verification passed.
- Output: `dist/BrowserScope.app`. Local use only; not notarized or tested on Intel.

## Automated coverage

1. Independent browser roots and verified helper aggregation; excludes unrelated native messaging hosts.
2. macOS code-sign clone root paths use the kernel's original launch path to group installed helpers.
3. Shared Playwright launcher: two instances retain separate members and Codex attribution.
4. Headless temporary profile qualifies for bulk cleanup; standard/custom/missing profiles and headed/unknown mode do not.
5. Headless alone does not imply automation or safe cleanup.
6. Missing RSS and Safari are marked partial.
7. BrowserScope and its ancestor browser are protected.
8. Same-executable renderers are not treated as independent browser instances.
9. A visited Playwright website is not treated as Playwright launch evidence.
10. Changed start time, changed executable and another UID are rejected by the signal boundary.
11. Ancestor protection and permission-denied signal results.
12. Page counting deduplicates IDs and excludes workers, iframes and extension pages.
13. Real disposable `/bin/sleep`: kernel identity and argv read, normal TERM, verified exit.
14. Still-running root returns an explicit result without automatic force escalation.
15. Root gone / helper alive returns partial close with remaining PIDs.
16. Same temporary profile with a new identity returns possible restart; no second signal.
17. Explicit force uses SIGKILL; reused helper PID is not signalled.
18. Bulk policy is re-resolved before a signal, rather than trusting the cached profile.

## Real Chrome integration

`python3 scripts/integration-test.py` passed, including a rerun after the termination dependency boundary changed.

The script starts two Chrome processes with separately generated `/tmp/browser-scope-test-*` profiles. One instance aggregated **10 processes**, reported nonzero RSS, and exposed **2 pages** through its process-owned DevTools endpoint. The other independently reported **1 page**. A deliberately wrong start time was rejected. Closing the first fixture returned Closed and left the other browser running; the second fixture was then closed and verified exited. Fixtures clean up their own processes and temporary directories.

Existing user Chrome instances were only read. Real scanning found both an existing headless instance and a normal Chrome instance. Their helpers were aggregated after fixing macOS code-sign clone paths. Pipe-only and normal no-CDP instances correctly returned unknown page counts. Their existing source cannot be reconstructed beyond available ancestry/fingerprints, and is not fabricated.

## Native UI validation

The app launched as an accessory/menu-bar app and the real popover accessibility tree exposed the expected summary, source rows, memory, pages, filters and actions. The computer-use screenshot API timed out for the transient popover; inspection continued in the app's explicit `--demo --preview-window` mode, using the same SwiftUI panel.

Actual native preview screenshots and UI actions verified:

- Source-first layout, prominent memory/page columns and native controls in dark appearance.
- Headless filter removes the Safari row; All restores it.
- Expand details shows profile, member PIDs, inferred source evidence and launcher.
- Protecting an instance changes bulk eligibility from 4 to 3.
- Bulk confirmation lists selected instances and the protected instance's skip reason.
- Cancel preserves the original 5 instances.
- Confirmed demo bulk cleanup leaves the protected headless instance and Safari.
- Force quit has its own explicit confirmation.
- Removing the last demo headless instance displays the empty state and disables bulk cleanup.
- Standard-profile/unknown-source/unknown-pages detail state.
- Final release reopened in normal mode: the actual popover displayed 2 live instances (one headless Playwright fingerprint, one normal Chrome), aggregated RSS, and unknown-page fallbacks.
- Escape was dispatched to the transient popover, but subsequent accessibility inspection timed out; keyboard dismissal is not counted as verified.

Demo operations never call the signal gateway. Real termination was exercised independently by the integration test. The optional preview window is a development aid; default operation is the menu-bar popover.

## Remaining validation limits

- Launch-at-login registration and actual sleep/wake behavior are implemented but not exercised by changing the user's login settings or suspending this machine.
- Safari normal quit, Edge/Firefox process behavior, Intel, macOS 14 and light appearance have not all been tested on real installations. Chromium code paths and Safari partial-memory behavior have unit coverage.
- Partial close, restart, permission denial and force identity races use deterministic boundary tests, not disruptive tests on the user's live applications.
- Renderer count is never substituted for page count. Most private Playwright pipe sessions will show unknown pages until an explicit reporting integration is added.
- Arbitrary Playwright WebKit/MiniBrowser and orphaned helpers without a verifiable root are not fully supported by this MVP.
- The check-to-signal race cannot be eliminated by these user-space APIs; PID/start/path revalidation narrows it.
- A helper left after a partial close is reported; this version does not retain a separate orphan-helper cleanup action.
- Keep protection lasts for the current app session. Close others, launcher termination, automatic cleanup and profile deletion remain out of scope.

## Follow-up UI optimization

- **19 tests passed**, including a new paired test for personal-browser presentation versus unknown arguments, headless mode, remote debugging, enable-automation and temporary profiles.
- Release rebuilt and signature verified.
- Native screenshots inspected at 400pt width; final live panel is approximately 400 × 432pt. Browser title, type, memory, pages, permanent row close buttons and overflow controls fit.
- Actual status-bar panel tested: Headless/All filtering, direct row close confirmation, Cancel, and continued panel visibility. Final borderless panel also tested with a real Chrome confirmation followed by Cancel; no live browser was closed.
- Live Chrome and Safari displayed their browser names and Personal browser, replacing the unknown-source primary label.
- External click was exercised with Calculator; subsequent BrowserScope accessibility inspection timed out while hidden. This is limited evidence, not a screenshot verification of the hidden state. Internal-click/confirmation retention was positively verified via the accessibility tree.
- Replaced transient NSPopover with a persistent, key-capable borderless NSPanel. Added screen-bound clamping after observing inaccessible offscreen placement from the status-item anchor.

## BroClean 0.2.0 — 2026-09-11

- Product executable and app bundle renamed BroClean; bundle identifier and existing preferences retained. Version displayed from Info.plist: 0.2.0, build 2. Current output is `dist/BroClean.app`.
- **23 tests passed**. New coverage: numeric sorting in both directions with missing values last; name/type/browser/PID/age sorting; automated bulk scope includes headed temporary-profile automation and excludes personal/standard profiles; fresh policy revalidation before automated signals.
- Native UI verified in demo mode: Memory toggles descending/ascending with correctly reordered rows. Automated confirmation included all four automation fixtures, including a headed instance; confirmed demo cleanup preserved personal Safari. No live browser was terminated by this UI test.
- Settings menu displayed BroClean 0.2.0, GitHub and repository configuration. Missing URL opens the configuration sheet; Save is disabled for empty/invalid input. No repository address has been supplied and no remote exists, so no repository URL was invented or published.
- Notifications/results moved inside the fixed-height scroll area so cleanup controls remain visible.
- Release app rebuilt and signature verified. Old generated BrowserScope.app removed to avoid launching the obsolete version.

## Native CLI — 2026-09-11

- Added broclean executable and BroCleanCLIKit. 29 Swift Testing tests passed.
- Real disposable-Chrome CLI integration passed: JSON list/inspect, correct page count, --dry-run no signal, missing confirmation exit 2, stale identity exit 3, shared protection and --exclude planning, verified normal close, sibling isolation, stopped root returning Still running/exit 4, then explicit --force producing Closed.
- Existing user/test-lab browsers were not selected by real close commands.
- Desktop and CLI now share durable bulk protection. The original in-memory-only protection limitation is superseded for the rebuilt application.
- CLI documentation records schema, exit codes, command examples, optional installation and the distinction between bulk protection and an explicit individual close.

- A clean combined build exposed the case-insensitive BroClean/broclean product-name collision. Desktop's internal SwiftPM product was renamed BroCleanDesktop while preserving its .app name; CLI remains broclean. Both products are rebuilt separately and together for delivery.
