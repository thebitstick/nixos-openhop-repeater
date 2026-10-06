#!/usr/bin/env bash
# Refreshes the files in this repository that are generated or copied from elsewhere:
#   docs/options.md     the option reference, generated from module.nix
#   radio-presets.json  upstream's preset list, at the version package.nix pins
# Run it after changing options or bumping the openHop version. Needs Nix and, on macOS, a Linux builder.
set -euo pipefail
cd "$(dirname "$0")/.."

# Evaluate and build for Linux whatever the host is; the output does not depend on the architecture.
host=$(nix eval --impure --raw --expr 'builtins.currentSystem')
linux=${host/-darwin/-linux}

echo "Updating docs/options.md ..."
doc=$(nix build ".#packages.$linux.options-doc" --no-link --print-out-paths)
install -m 0644 "$doc" docs/options.md

echo "Updating radio-presets.json ..."
src=$(nix build ".#packages.$linux.openhop-repeater.src" --no-link --print-out-paths)
install -m 0644 "$src/radio-presets.json" radio-presets.json

git status --short docs/options.md radio-presets.json
