#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product broclean
mkdir -p dist
install -m 755 .build/release/broclean dist/broclean
codesign --force --sign - --timestamp=none dist/broclean
codesign --verify --strict dist/broclean
printf 'Built %s/dist/broclean\n' "$PWD"
