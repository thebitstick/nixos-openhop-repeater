# Changelog

## Unreleased

- Package openhop_repeater 1.1.4 / openhop_core 1.1.3.
- Module `services.openhop-repeater`: repeater, radio, MQTT and mesh options, companions, room servers,
  `settings` escape hatch, secrets via `*File` options, `repeater.identityKeyFile`.
- Regional profile `chicagolandMesh`.
- `package` now has a default, so the module works without the flake.
- Assertions for missing radio settings, clashing names and ports, and out-of-range coordinates.
- Tests (`nix flake check`) and a GitHub Actions workflow.
