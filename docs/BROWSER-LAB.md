# Browser test lab

From the project directory:

```sh
./scripts/browser-lab.sh start
./scripts/browser-lab.sh status
./scripts/browser-lab.sh stop
```

`start` launches six independent Chrome instances with **real Playwright/Puppeteer controllers**, not spoofed process names. It runs in the background and reuses an active lab instead of duplicating it. `stop` asks the live lab to close only its own browser handles and child processes; it never kills processes by name or by PIDs loaded from disk. If you close an instance in BroClean it stays closed; the lab does not relaunch it. Run stop then start to restore all fixtures.

## Scenarios and initial expectations

| Scenario | Mode | Initial pages | BroClean Pages | Bulk cleanup |
|---|---|---:|---:|---|
| playwright-pipe | Headless, private pipe | 2 | — | Eligible |
| playwright-cdp | Headless, pipe + TCP CDP | 3 | 3 | Eligible |
| playwright-headed | Headed, pipe + TCP CDP | 2 | 2 | Excluded |
| puppeteer-cdp | Headless, TCP CDP | 4 | 4 | Eligible |
| custom-headless | Headless, custom profile + CDP | 1 | 1 | Excluded |
| personal-headed | Headed, isolated standard-profile layout | 2 | — | Excluded |

The three Playwright instances share one launcher. Closing one browser should leave its siblings running. The personal fixture deliberately uses a standard directory layout **inside the lab's own temporary directory**, to test the Personal browser presentation without accessing the user's actual Chrome profile. The custom headless fixture deliberately has no framework fingerprint; Unknown source is expected.

Every page is a labeled local test page served on 127.0.0.1. Each fixture gets its own profile. There are no external page navigations, accounts, user-profile access or task-name impersonation. BroClean reads source attribution naturally from the actual controller ancestry. The detached launcher does not pretend to be Codex or Claude.

## Dependencies and state

- Node.js with npm and Google Chrome installed locally.
- First start runs `npm ci` for pinned `playwright-core` and `puppeteer-core` dependencies. No extra browser binaries are downloaded.
- Override the compatible Chrome executable with `BROWSER_LAB_CHROME` if needed.
- `.browser-lab/session.json` stores fixture PIDs, profiles, expectations and a local control token. `.browser-lab/session.log` records launcher errors. Both are git-ignored.
- Controller binds to loopback and requires a per-run random token for status/stop. Ordinary test-page requests cannot stop it.
- Temporary profile directories are retained after stop for inspection. The script does not delete browser data or automatically send SIGKILL.
- `status` reports launch expectations and known lifecycle state, not live tab counts after manual edits. BroClean itself shows live counts where CDP is available.

## Verified on this machine

All six instances launched. BroClean's production diagnostics confirmed every expected page count/unknown fallback and bulk eligibility; the three Playwright instances reported a shared launcher. A stop/start cycle was exercised while fixing explicit Puppeteer TCP-port configuration. No existing user browser was selected by the lab's stop command.

API references: [Playwright BrowserType](https://playwright.dev/docs/api/class-browsertype), [Puppeteer LaunchOptions](https://pptr.dev/api/puppeteer.launchoptions). Package versions are pinned in `scripts/browser-lab/package-lock.json`.
