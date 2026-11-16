#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command="${1:-start}"
case "$command" in
  start)
    if [[ ! -d scripts/browser-lab/node_modules/playwright-core || ! -d scripts/browser-lab/node_modules/puppeteer-core ]]; then
      npm ci --prefix scripts/browser-lab --ignore-scripts --no-audit --no-fund
    fi
    ;;
  status|stop) ;;
  *) printf 'Usage: %s [start|status|stop]\n' "$0" >&2; exit 1 ;;
esac
exec node scripts/browser-lab.cjs "$command"
