#!/usr/bin/env bash
# Runs a design/ node script with nix-provided node + Playwright browsers.
#   design/run.sh design/capture.mjs
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PW=$(nix build --no-link --print-out-paths nixpkgs#playwright)
BROWSERS=$(nix build --no-link --print-out-paths nixpkgs#playwright-driver.browsers)

mkdir -p design/node_modules
ln -sfnT "$PW" design/node_modules/playwright-core
export PLAYWRIGHT_BROWSERS_PATH="$BROWSERS"

exec nix shell nixpkgs#nodejs_22 -c node "$@"
