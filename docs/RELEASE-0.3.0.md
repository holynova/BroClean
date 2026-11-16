# BroClean 0.3.0

Release date: 2026-11-16. Apple Silicon, macOS 14 or later.

- Adopt the grouped native interface: blue tonal hierarchy and monochrome source marks.
- Add a close control per visible group, with frozen target review, protected-item exclusions, and an explicit warning for personal browsers.
- Show batch progress and allow stopping the remaining work.
- Move protection-file reads/writes off the main actor and label incomplete total-memory estimates.
- Adopt approved app icon A (stacked windows), with all standard macOS ICNS sizes.
- Update desktop and CLI version strings to 0.3.0.

The source PNG and generation provenance live in `design/icon-source/`. `scripts/build-app.sh` generates the icon, packages it and signs the app locally. CLI builds remain available through `scripts/build-cli.sh`.

This local build uses an ad-hoc signature and is not Apple-notarized. Repository and release assets: https://github.com/holynova/BroClean/releases/tag/v0.3.0. Existing performance-audit findings outside these changes remain open.

Validation: 33 Swift Testing tests passed; Release build, full ICNS export, and strict app signature verification passed on Apple Silicon. Native demo group-close and cancellation behavior were verified during UI review.
