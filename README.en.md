<p align="right"><a href="README.md">中文</a></p>

<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="BroClean — a menu bar manager for browser instances: three stacked browser windows labeled Playwright, Claude (protected), and Codex, with a green protection shield at the bottom right">
</p>

<p align="center">
  <a href="https://github.com/holynova/BroClean/releases/latest"><strong>▶ Download for macOS</strong></a>
  ·
  <a href="https://github.com/holynova/BroClean/releases/tag/v0.3.0">What's new in 0.3.0</a>
</p>

After AI tools or automated tests finish, browsers can keep running in the background. BroClean is a native macOS menu bar app that shows browser instances, their inferred launch source and resource usage together — so you see the full picture before closing anything: protect the instances still in use, then clean up the rest by group. Native SwiftUI + AppKit, macOS 14+, Apple Silicon.

## Screenshots

<p align="center">
  <img src="./assets/readme/browser-groups.png" width="360" alt="BroClean's native grouped interface: the automated group holds Playwright, Claude, Codex, and ChatGPT with Claude protected; the personal group holds Safari; each group has its own close button">
  <img src="./assets/readme/close-review.png" width="360" alt="Close confirmation for the automated group: three instances listed for closing, with protected Claude explicitly skipped">
</p>

*Real native app screenshots using demo data. The interface is currently in English; demo mode never closes real processes.*

## From Discovery to Close

- **Identify the source**: monochrome icons and source names locate each instance; expand for inference evidence, launcher and process info. Sources are inferred from process relationships and launch arguments — not an official integration with the named app.
- **Narrow it down**: filter across All / Automated / Headless; sort by memory, pages, age and more.
- **Protect your work**: protection persists by process identity (PID + kernel start time) and is shared with the CLI; group and bulk cleanup skip protected items.
- **Review before closing**: the `×` on a group header shows exactly what will close and what will be skipped. Only the currently visible group is affected; the Personal group gets an extra warning that closing may interrupt windows and work.
- **Bulk, with restraint**: watch progress and stop remaining tasks during bulk runs. Closing a single instance and force-quitting are separate actions; an ordinary close never escalates to a force quit on its own. A protected item can still be closed through an explicit single-instance action.
- **Nothing extra**: no automatic cleanup, no deleting browser profiles or user data; process identity, owning user, and executable path are re-verified before any termination request is sent.

## Reading the Numbers

| Shown as | Meaning and limits |
| --- | --- |
| Source name | Inferred from process relationships and launch arguments; not an official integration with the named app. |
| Memory | A process-tree RSS estimate, not the memory that closing would free; `+` means the data is incomplete. |
| Page count | Read from local, process-owned CDP endpoints when available; `—` when unreadable — never faked from process counts. |
| Safari | App-level identification only; shared WebKit services are excluded from its memory total, and page counts are unavailable. |

Coverage includes Chrome, Chrome for Testing, Chromium, Edge, Firefox and Safari; the data each browser can provide differs. Automated bulk cleanup also excludes standard configurations and uncertain instances.

## Get Started

1. Download `BroClean-0.3.0-macOS-arm64.zip` from [Releases](https://github.com/holynova/BroClean/releases/latest) and unzip it to get `BroClean.app`.
2. Move the app into Applications, open it, and click the BroClean icon in the menu bar to see the list.
3. Click a source name to see how it was identified; protect instances that should keep running from the `…` menu at the end of the row.

The installer is for **Apple Silicon / macOS 14 or later**; running the app needs no Swift, Node.js, or Python install. The current release uses a local ad-hoc signature and has not been Apple-notarized. Each release includes a SHA-256 checksum file.

## CLI & Building from Source

Requires macOS 14+ and the **Swift 6 toolchain**. The app and the CLI have no third-party runtime dependencies.

```sh
git clone https://github.com/holynova/BroClean.git
cd BroClean
swift test --disable-xctest
./scripts/build-app.sh
open dist/BroClean.app
```

The CLI shares the app's scanning, closing, and protection logic. List first, then preview the cleanup scope:

```sh
./scripts/build-cli.sh
./dist/broclean list --sort memory --desc
./dist/broclean close --headless --dry-run
```

`--dry-run` prints the plan and sends no termination signals. JSON output, per-instance actions, and protection commands are in the [CLI docs](docs/CLI.md).

<details>
<summary>Just want to look at the UI? Use demo mode</summary>

Quit any running BroClean first, then run from the source build directory:

```sh
open dist/BroClean.app --args --demo --preview-window
```

Demo mode uses sample instances; a normal launch reads the real processes on your machine.

</details>

## Learn More

- [Architecture & Implementation](docs/ARCHITECTURE.md) · [UI Design Spec](DESIGN.md)
- [0.3.0 Release Notes](docs/RELEASE-0.3.0.md) · [Validation Record](docs/VALIDATION.md)
- [Repeatable Browser Lab Scenarios](docs/BROWSER-LAB.md) · [Product Behavior Spec](docs/PRODUCT-SPEC.md)

0.3.0 passes **33 Swift Testing tests** and has completed release builds, app signing, and installer verification. Broader system compatibility and long-running validation are still ongoing. If you hit a problem, please report it via [Issues](https://github.com/holynova/BroClean/issues) with your macOS version, browser type, and steps to reproduce.
