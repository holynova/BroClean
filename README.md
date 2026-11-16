# BroClean

<img src="design/icon-source/A-stacked-windows.png" width="96" alt="BroClean stacked-window icon">

A native macOS menu bar app for inspecting and closing browser instances left by AI tools and tests. Source-first rows, Headless/Headed mode, estimated process-tree memory, best-effort page counts, and precise process identity checks.

Download: [BroClean 0.3.0 for Apple Silicon](https://github.com/holynova/BroClean/releases/download/v0.3.0/BroClean-0.3.0-macOS-arm64.zip) · [Release notes and assets](https://github.com/holynova/BroClean/releases/tag/v0.3.0)

Current release: **0.3.0** — grouped interface and approved stacked-window app icon. See [release notes](docs/RELEASE-0.3.0.md).

Requires macOS 14+ and the Swift 6 macOS toolchain. No external dependencies.

```sh
swift test --disable-xctest
./scripts/build-app.sh
open dist/BroClean.app
```

Read-only diagnostics:

```sh
swift run browser-scope-diagnostics scan
```

Documentation: [Product and acceptance spec](docs/PRODUCT-SPEC.md), [Architecture](docs/ARCHITECTURE.md), [Validation](docs/VALIDATION.md), [HeadlessGuard comparison](docs/HEADLESSGUARD-COMPARISON.md), [Existing tools](docs/EXISTING-TOOLS.md).

Pages are unknown when a browser exposes no accessible process-owned CDP endpoint (including pipe-only automation). Memory is an RSS estimate, not guaranteed reclaimable memory. Safari has app-level support; its shared WebKit services are not guessed into its memory total. Bulk close skips protected, standard-profile, and uncertain instances and reports why. No automatic cleanup or profile deletion.

The current UI uses the grouped index documented in `DESIGN.md`. The older image in `design/approved-ui.png` is a historical concept. Real data is the default. `BroClean --demo` is an explicit visual-preview mode and never sends process signals.

The test suite uses Swift Testing, available in Command Line Tools; `--disable-xctest` avoids requiring a full Xcode installation. Optional real Chrome integration: `python3 scripts/integration-test.py` (build debug binaries first with `swift build`). This creates and closes two disposable browsers; existing instances are never selected.

To inspect the UI without touching processes, run `open dist/BroClean.app --args --demo --preview-window` after quitting the running copy. Omit both flags for normal menu bar operation. Protection is persisted by process identity and shared with the CLI; filters and sorting are remembered. Each group’s X reviews only that visible group and skips protected entries. Personal groups require an explicit warning and confirmation.

For interactive manual testing, run `./scripts/browser-lab.sh start` to leave six disposable browsers (14 local pages) running. Use `status` to inspect them and `stop` to clean up the lab. See [test scenarios](docs/BROWSER-LAB.md).

## CLI

```sh
./scripts/build-cli.sh
./dist/broclean list --sort memory --desc
./dist/broclean close --headless --dry-run
```

Supports JSON, inspect, interactive/explicit close, automated cleanup, single-instance force quit and protection shared with the desktop app. See [CLI commands and exit codes](docs/CLI.md).
