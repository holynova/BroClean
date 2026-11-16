# BroClean CLI

Native macOS CLI sharing the desktop application's scanner, aggregation, sorting, page reader and termination coordinator. Requires macOS 14+. No Node/Python dependency for normal use.

## Build and run

```sh
./scripts/build-cli.sh
./dist/broclean --help
./dist/broclean list
```

Optional installation into a directory already on your PATH:

```sh
mkdir -p "$HOME/.local/bin"
install -m 755 ./dist/broclean "$HOME/.local/bin/broclean"
```

This does not modify shell startup files. If `~/.local/bin` is not on your PATH, use the full executable path or configure your shell yourself.

## Inspect and sort

```sh
./dist/broclean list --headless
./dist/broclean list --automated --sort memory --desc
./dist/broclean list --sort pages --asc --json
./dist/broclean list --no-pages
./dist/broclean inspect 12345 --json
```

Replace example PIDs with a root PID from the current list. The default command is list. Sort keys are `name`, `type`, `browser`, `memory`, `pages`, `pid`, `age`. Unknown memory/page values always sort last. `--no-pages` skips local debugging-endpoint requests; it does not substitute renderer count for pages. Shared launchers, inference evidence and member PIDs are available in inspect/JSON output. Raw arguments, page titles/URLs and profile paths are not exported.

## Close with a reviewable plan

```sh
./dist/broclean close --headless --dry-run
./dist/broclean close --automated --exclude 12345,23456 --dry-run --json
./dist/broclean close 12345
```

A normal close asks for `yes` in an interactive terminal. Redirected/noninteractive stdin requires explicit `--yes`; otherwise it exits without sending a signal. For scripting after reviewing a plan:

```sh
./dist/broclean close 12345 --start-time 1789000000000000 --yes --json
./dist/broclean close --automated --yes --json
```

The example start time must be replaced with `startMicroseconds` from the actual list/inspect JSON. This is recommended when a PID is carried between commands. Without `--start-time`, the current browser at that PID is selected and then its current identity is frozen and revalidated before termination.

`--dry-run` always takes precedence over `--yes`/`--force` and sends no signals. Bulk cleanup requires a matching scope, temporary profile and no protection/exclusion; a headless flag alone is insufficient. Automated scope includes headed automation with a recognized temporary profile. Single-instance close may select a standard/personal profile after confirmation. The app, ancestors and other-user processes remain protected by the signal boundary.

Force quit is explicit, single-instance only:

```sh
./dist/broclean close 12345 --force --yes
```

There is no automatic escalation, launcher/ancestor kill, profile deletion or automatic relaunch. Every close checks the outcome and reports partial/still-running/restarted/refused states.

## Shared protection

```sh
./dist/broclean protect 12345
./dist/broclean unprotect 12345
```

Protection now persists and is shared with the rebuilt desktop app at `~/Library/Application Support/BroClean/protected-instances.json`. It is keyed by PID **and kernel start time**, so PID reuse does not protect an unrelated future process. Writers lock and atomically replace the file. An unreadable protection file blocks CLI operations and causes the shared termination coordinator to refuse bulk cleanup.

Protection excludes instances from bulk cleanup; an explicitly selected single-instance close remains available, as in the desktop app. Old identity records are harmless and may remain after a process exits. CLI unprotect currently requires a live instance; this release has no stale-record management command. Desktop selections made only in memory before this update cannot be recovered; protection selected in the new build persists.

## Machine output and exit status

Data commands support `--json`. Stdout contains one object with `schemaVersion: 1`, `command`, `dryRun`, `cancelled`, `instances`, `skipped`, and `results`. List/inspect rows include root PID/start identity, source, mode, profile category, RSS, pages, protection and member PIDs. Unknown optional values are omitted. Dates are ISO 8601. A dry-run returns only selected instances and explicit skip reasons; it does not return fabricated close results.

Prompts and errors go to stderr; `--json` errors are JSON objects with `error` and `exitCode`. Help/version are plain text.

| Code | Meaning |
|---|---|
| 0 | Successful read/protection change/close, empty bulk selection, dry-run or user cancellation |
| 1 | Runtime or filesystem error |
| 2 | Invalid arguments or missing noninteractive confirmation |
| 3 | Browser not found or expected start time differs |
| 4 | Single target refused, or at least one close is incomplete/refused/restarted |

Bulk skips are explicit but do not alone make the command fail; inspect `skipped` if your automation treats skips as an error. This is a snapshot CLI, not a daemon or watch command. Native browser-family/CDP limitations match the app. No root privileges are requested.

## Verification

```sh
swift test --disable-xctest
swift build
python3 scripts/integration-cli-test.py
```

29 unit tests passed, including strict option/target parsing, close planning, shared identity protection and corrupted-store fail-closed behavior. The real integration test creates only disposable Chrome children and validates JSON reads, page counts, no-signal dry-run, confirmation gating, stale identities, protection/exclusion, normal close, sibling isolation, stopped-root timeout and explicit force quit. Existing browsers are never selected by its real close commands.
