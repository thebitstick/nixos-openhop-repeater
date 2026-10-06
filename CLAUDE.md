# CLAUDE.md

Guidance for Claude (or any contributor) working in this repository.

## What this is

A NixOS module and package for [openHop Repeater](https://github.com/openhop-dev/openhop_repeater), a Python
MeshCore repeater daemon, so it can be configured declaratively as `services.openhop-repeater.*`. MIT licensed
(same as openHop and MeshCore). The Nix code is AI-written; keep `AI-DISCLOSURE.md` truthful when that changes.

## Layout

| Path | Purpose |
| --- | --- |
| `module.nix` | the NixOS module: options, config rendering, assertions, systemd unit |
| `package.nix` | builds `openhop_repeater` (1.1.4) and its pinned `openhop_core` (1.1.3) |
| `presets.nix`, `radio-presets.json` | regional radio presets; the JSON is an unmodified copy of upstream's |
| `scripts/convert-firmware-key.py` | MeshCore private key to openHop key file (packaged as `convert-key`) |
| `scripts/update-generated.sh` | refreshes `docs/options.md` and `radio-presets.json` |
| `docs/options.md` | generated option reference (never edit by hand) |
| `tests/` | the flake checks |
| `examples/` | region-neutral example configuration |

## Commands

```
nix flake check                                 # everything; needs a Linux builder, not KVM
nix build .#checks.aarch64-linux.<name>         # one check (names: nix eval .#checks.aarch64-linux --apply builtins.attrNames)
nix fmt                                         # nixfmt-tree; CI uses `nix fmt -- --ci`
scripts/update-generated.sh                     # after changing options or bumping openHop
nix run .#convert-key -- --help
```

- The Linux builder may be absent (the author removed it). Evaluation, the docs and the key converter still work
  on macOS; the other checks need Linux, or CI.
- On macOS, builds need a Linux builder (`nix.linux-builder.enable = true` in nix-darwin). Use explicit
  systems on a Mac: `.#packages.x86_64-linux.openhop-repeater.src`, not `.#openhop-repeater.src`.
- **Flakes only see git-tracked files.** `git add` new files before `nix build`, or you get "not tracked by Git".
- Test against more than unstable before claiming compatibility:
  `nix build --override-input nixpkgs github:NixOS/nixpkgs/nixos-26.05 ...` (and `nixos-25.11`). Leave out
  `docs-in-sync` when overriding: nixpkgs formats the generated Markdown differently per release (25.11 differs
  from unstable in 416 lines of formatting, none of content), so that check only holds for the locked nixpkgs.
- Bumping openHop: edit `package.nix` (version, hash, and the core version upstream pins), run
  `scripts/update-generated.sh`, run `nix flake check`.
- A real-service test needs a NixOS VM (`system.build.images.qemu-efi`), run with `radio.type = null`. The VM has
  internet access: disable MQTT in it, or it publishes to public brokers.

## Design decisions to preserve

- **`config.yaml` is regenerated from Nix at every start** into the state directory, then secrets are merged in
  by `ExecStartPre`. Nix is the source of truth; edits made in openHop's web UI do not survive a restart.
- **Secrets never reach the Nix store.** Anything secret is a `*File` option loaded with `LoadCredential`. A test
  asserts no `identity_key` / `*_password` / `jwt_secret` in the rendered config. Never add a secret as a plain
  option.
- **Never let the node generate a new identity by accident.** A repeater's identity is its public address.
  `repeater.identityKeyFile` is installed at every start for that reason.
- **Region-neutral.** No regional profile belongs in the module (an earlier `chicagolandMesh` option was
  removed). Region comes from `radio.preset`; networks and brokers are the user's `mqtt.*` settings. Personal or
  regional settings go in the user's own configuration, not here.
- **Presets:** an explicit `radio.*` setting beats the preset, which beats nothing. Without a preset all four of
  frequency, bandwidth, spreading factor and coding rate are required (assertion). `txPower` is never part of a
  preset. Convert MHz/kHz with integer string maths, never floats.
- Companion `bindAddress` defaults to `127.0.0.1` because the TCP port has no authentication.
- Mistakes are caught by assertions with a clear message, and each has a `rejects-*` check.

## Upstream facts (verified in openHop's source)

- **Passwords are plain text and compared as plain strings** (dashboard and mesh login). Hashing would need an
  upstream change. The README says so; do not imply otherwise.
- Key formats: `identity.key` is base64 of 32 or 64 raw bytes; companion and room identities are 64 or 128 hex
  characters. A 64-byte MeshCore key is `[32-byte scalar][32-byte nonce]`. `openhop_core` derives the public key
  with libsodium's unclamped base-point multiplication, which **ignores bit 255**; the converter matches that
  (a test found the mismatch).
- Config keys do not always match option names: `repeater.name` is `node_name`; `mqtt_brokers.owner` is a public
  key, not a secret. `config.yaml.example` in the upstream repo is the reference for every key.
- Bundled MQTT broker presets: `chimesh`, `letsmesh`, `meshat-se`, `meshcore-ca`, `meshmapper`, `waev`.
- Upstream's own `convert_firmware_key.sh` takes the key as an argument (visible in the process list) and needs
  root; ours does not.

## Working agreements

- **Ask before outward or irreversible actions:** pushing, committing in someone else's repo, anything on a live
  server, deleting data. Approval for one does not carry to the next.
- **Never touch the user's uncommitted work.** Do not `git stash`, `reset` or `checkout` in their repositories
  to compare things. Copy files aside instead.
- **Servers: read-only first.** Redact secrets on the machine before output reaches you, compare secrets by
  checksum or derived value, and show the user the plan before changing anything. `sudo` there needs an
  interactive password, so give the user the command (use `ssh -t`) rather than trying it.
- **Be honest about verification.** Say what was tested and what was not; a README command that was never run
  has been wrong before (it failed on macOS). Prefer a test that can fail over a claim.
- **No comments unless the code is not self-explanatory.** The author finds narrating comments a mark of AI-written
  code. Comment only a non-obvious *why* (a trap, an upstream quirk), never what the code already says. Option
  `description`s and the docs are documentation, not comments.
- **Public repo hygiene:** no personal data (names, coordinates, hostnames, IPs, emails, keys) in tracked files.
  Examples use placeholders. Scan before pushing.
- **Clean up** scratch files, VMs and containers you create, and say what you touched when asked.
- Commits made with Claude's help end with the `Co-Authored-By` trailer; the user is the author.

## Shell gotchas

- Remote login shells may be Nushell: send scripts as `ssh host bash -s <<'EOF'`. A `2>&1` in a plain `ssh host '...'`
  command is a Nushell error.
- Use `docker exec -i` when feeding a script on stdin.
- When running upstream code locally, set `HOME` to a scratch directory: `load_config` generates an identity key in
  `~/.config/openhop_repeater` when none is configured, and that is how a stray key once landed in the user's home.
  Unix socket paths on macOS are limited to about 100 characters, so keep test sockets in a short path.
- macOS has bash 3.2: no empty-array expansion under `set -u`. zsh does not split unquoted variables, and
  `PIPESTATUS` is `pipestatus` there; quote globs such as `--include='*.py'`.
- Do not read `optionalAttrs` conditions from an option inside the same attribute set that defines it: infinite
  recursion. Use `mkIf` (this happened with the old profile).

## The author's deployment (context only)

- One production repeater on a NixOS x86_64 server, `minto`, defined in the author's separate `nix` repository
  (`hosts/specialization/Minto.nix`), which uses this repo as a flake input. It was migrated from Docker; the
  Docker setup is gone.
- It uses an openHop Modem on a Heltec V3 (`modem_usb`), the USA/Canada preset with 3-byte path hashes, and
  `monitor` mode. Secrets live in `/var/lib/openhop-secrets` on the host.
- Its `flake.lock` pins a module revision, so pushing here changes nothing there until the author runs
  `nix flake update openhop-repeater` and rebuilds. Ask for the SSH address; it is not recorded here.
