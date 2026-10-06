# AI disclosure

This project was built with AI assistance.

## What the AI did

Almost all of the code and documentation in this repository was written by **Claude** (Anthropic; Claude
Sonnet 5.5, run through Claude Code) in a back-and-forth session with the project's author:

- `package.nix`, `module.nix`, the key converter in `scripts/`, the tests in `tests/`, the CI workflow, and the
  documentation.
- Research into upstream openHop Repeater (its `config.yaml.example`, source and documentation), from which
  the module's options were derived. The radio presets are upstream's own data file, not AI-generated.
- Commits made with Claude's help carry a `Co-Authored-By: Claude` trailer.

## What the human did

The author decided what to build, supplied the real-world requirements and hardware, and ran and observed the
result on their own machines. The module was used to move a live repeater from Docker to NixOS.

## What was tested

- `nix flake check` passes on nixos-unstable, 26.05 and 25.11 (build of the package, the rendered
  configuration, radio presets, the start-up script with fake secrets, rejected configurations, and the key
  converter, whose public keys are compared with openhop_core's own derivation for 120 keys).
- The service was run in a NixOS virtual machine, **without a radio** (`radio.type = null`): it starts, loads
  companions and room servers, and takes its configuration.
- It runs on one production repeater, **an openHop Modem (Heltec V3) over USB (`radio.type = "modem_usb"`)**.
  There the identity was preserved across the migration, the radio received traffic, and a connection to the ChiMesh MQTT broker was established.

## What was not tested

- The `sx1262`, `sx1262_ch341`, `kiss` and `modem_tcp` radio backends. Their options follow upstream's
  documentation but have never been run against hardware.
- GPS, sensors, the plugin manager (not packaged), and anything else not listed above.
- The GitHub Actions workflow, which could not be run from the development machine.

## Caveats

- AI-written code can contain mistakes that look plausible. It has not had an independent human security
  audit. The module runs a network service and handles passwords and cryptographic identity keys; read
  `module.nix` before trusting it with a node you care about.
- Back up your repeater's identity key before changing anything (see the README).
- Please report problems as issues. Pull requests are welcome, AI-assisted or not; please say which.
