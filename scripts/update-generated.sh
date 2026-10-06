#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# the output does not depend on the architecture, so build for Linux even on macOS
host=$(nix eval --impure --raw --expr 'builtins.currentSystem')
linux=${host/-darwin/-linux}

echo "Updating docs/options.md ..."
doc=$(nix build ".#packages.$linux.options-doc" --no-link --print-out-paths)
install -m 0644 "$doc" docs/options.md

echo "Updating radio-presets.json ..."
src=$(nix build ".#packages.$linux.openhop-repeater.src" --no-link --print-out-paths)
install -m 0644 "$src/radio-presets.json" radio-presets.json

git status --short docs/options.md radio-presets.json
