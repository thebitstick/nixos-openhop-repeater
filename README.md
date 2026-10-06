# nixos-openhop-repeater

A NixOS module and package for [openHop Repeater](https://github.com/openhop-dev/openhop_repeater),
the Python [MeshCore](https://meshcore.co.uk) repeater daemon. Configure the daemon from Nix instead of
editing `config.yaml` by hand:

```nix
services.openhop-repeater = {
  enable = true;
  repeater.name = "My Repeater";
  repeater.latitude = 41.8781;
  repeater.longitude = -87.6298;
};
```

> Unofficial, and largely AI-written (see [AI-DISCLOSURE.md](AI-DISCLOSURE.md)). This project is not
> affiliated with or endorsed by openHop. It packages
> openhop_repeater **1.1.4** (with openhop_core **1.1.3**) and is tested against nixos-unstable,
> 26.05 and 25.11.

## Quick start

Add the flake input and the module to your system:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openhop-repeater = {
      url = "github:thebitstick/nixos-openhop-repeater";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, openhop-repeater, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # or aarch64-linux
      modules = [
        openhop-repeater.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Without flakes, `imports = [ /path/to/nixos-openhop-repeater/module.nix ];` works too.

Then in `configuration.nix` (see [`examples/example-repeater.nix`](examples/example-repeater.nix) for a fuller one):

```nix
services.openhop-repeater = {
  enable = true;
  openFirewall = true;          # web dashboard, port 8000 by default

  repeater = {
    name = "My Repeater";
    latitude = 41.8781;         # strings such as "41.8781" are accepted too
    longitude = -87.6298;
    security.adminPasswordFile = "/var/lib/openhop-secrets/admin";
  };

  radio = {
    type = "modem_usb";         # sx1262 | sx1262_ch341 | kiss | modem_tcp | modem_usb
    modemUsb.port = "/dev/serial/by-id/usb-...";
    preset = "eu-uk-narrow";    # your region's radio settings; see "Radio presets" below
  };
};
```

Apply with `nixos-rebuild switch`, then open `http://<host>:8000` and follow the logs with
`journalctl -u openhop-repeater -f`.

## Secrets

Passwords and identity keys are **never** put in the Nix store. Options ending in `File` take a path to a
file on the target machine, which systemd loads at start (`LoadCredential`), so root-owned `0600` files in a
`0700` directory are fine:

| Option | File contents | If you leave it unset |
| --- | --- | --- |
| `repeater.security.adminPasswordFile` | admin password | dashboard login does not work (build warning) |
| `repeater.security.guestPasswordFile` | guest password | no guest access |
| `repeater.security.jwtSecretFile` | e.g. `openssl rand -hex 32` | a new secret every restart, which logs everyone out |
| `repeater.identityKeyFile` | an existing `identity.key` | one is generated on first start |
| `companions.<name>.identityKeyFile` | 64 hex chars (`openssl rand -hex 32`) or 128 (firmware key) | required |
| `roomServers.<name>.identityKeyFile` | same as companions | required |

- The files must exist **before** the service starts, or the unit fails with a credentials error.
- Every identity needs its own unique key.
- Your repeater's identity is its address on the mesh. Back up `/var/lib/openhop_repeater/identity.key`
  (or the file you pass as `identityKeyFile`). If you replace it, the mesh sees a new node.
- **Passwords are stored in plain text.** That comes from openHop itself: it keeps `admin_password` and
  `guest_password` as plain text in its `config.yaml` and compares them as plain strings, both for the
  dashboard login and for logins over the mesh. Storing a salted hash instead would need a change in openHop,
  because the daemon would treat the hash as the password. What this module does about it: the password never
  enters the Nix store, the file you point to is read by systemd and is only readable by root, and the
  generated `config.yaml` is `0600` and owned by the service user. Use a long, unique password. The repeater
  password gives administrative control over the node, so do not reuse one you use elsewhere.
- To keep secrets encrypted in your repository, [sops-nix](https://github.com/Mic92/sops-nix) or
  [agenix](https://github.com/ryantm/agenix) paths work here, for example
  `config.sops.secrets.openhop-admin.path`.

## Plugins

The dashboard's Plugins page talks to a second service, the openHop plugin manager, and shows "Plugin manager is
unavailable" when it is not running. The module runs it by default (`plugins.enable = true`), as openHop's own
installer does, which makes the notice go away even if you never use plugins.

Running it lets a dashboard administrator install and run plugins, which is third-party code. If you do not want
that, set `plugins.enable = false` and accept the notice. Setting `plugins.enabled = false` in `settings` does
not hide the notice: that only stops the manager from starting.

## Moving an existing MeshCore node to openHop

To keep a MeshCore device's identity (its node address) when you move it to openHop Repeater, convert its
64-byte private key (128 hex characters) into a key file. openHop's own converter takes the key as a command-line
argument, which other users on the machine can read in the process list. This one does not:

```
nix run github:thebitstick/nixos-openhop-repeater#convert-key -- -o identity.key
```

It asks for the key with the input hidden (or use `--stdin` or `--key-file`), writes the file with mode `0600`,
and prints the **public** key and node hash. Compare those with what your MeshCore app shows before you rely on
the result. The private key is never printed, and an existing file is never overwritten without `--force`.

- `-o identity.key` writes the repeater's identity in the format openHop reads. Point
  `repeater.identityKeyFile` at it.
- `--format hex` writes the plain hex form that companion and room server identities use.
- `--check` only shows the public key and writes nothing.

Works on macOS and Linux and needs only Python. Afterwards, clear any shell history that contains the key, and
remove the plaintext key file you converted from.

## How the configuration is applied

`config.yaml` is regenerated from your Nix options, plus the secrets, **every time the service starts**, and
written to `/var/lib/openhop_repeater/config.yaml`. Consequences:

- Nix is the source of truth. Changes made in the web dashboard last until the next restart. Put anything you
  want to keep in your configuration.
- Anything upstream supports but this module has no option for goes in `settings`, which is merged over
  everything else. Do not put secrets there.
- `nix eval .#nixosConfigurations.<host>.config.services.openhop-repeater.renderedSettings --json` shows the
  final config without secrets.

## Radio backends

| `radio.type` | Hardware | Notes |
| --- | --- | --- |
| `modem_usb` | openHop Modem (e.g. Heltec V3) over USB | set `modemUsb.port`; use `/dev/serial/by-id/...` for a stable path |
| `modem_tcp` | openHop Modem over Wi-Fi/Ethernet | set `modemTcp.host` |
| `kiss` | KISS serial modem | set `kiss.port` |
| `sx1262` | SX1262 HAT on SPI/GPIO (Raspberry Pi) | pin numbers in `radio.sx1262`; enable SPI in your system |
| `sx1262_ch341` | SX1262 behind a CH341 USB-to-SPI adapter | optional `radio.ch341` for several adapters |
| `null` | none | the daemon runs without RF, useful for testing |

The service user is added to `dialout`, `plugdev`, `gpio` and `spi`, and udev rules grant those groups access
to SPI, GPIO and CH341 devices. The daemon runs as an unprivileged user, never as root. Its only extra
capability is `CAP_SYS_TIME`, and only if you enable `gps.enable`.

## Radio presets

Every region has its own radio settings. Set `radio.preset` to use one of openHop's, which are the same list its
setup wizard offers:

```nix
radio.preset = "usa-canada-recommended";   # 910.525 MHz / SF7 / BW 62.5 kHz / CR5
```

There are presets for Australia, Brazil, Costa Rica, the EU/UK (including 433 MHz), the Czech Republic,
Hungary, the Netherlands, New Zealand, Portugal, Slovakia, Switzerland, USA/Canada and Vietnam. The option's
documentation in [docs/options.md](docs/options.md) lists every name with its values. A preset sets the frequency,
bandwidth, spreading factor and coding rate, and a path hash size where the region defines one.

Settings you add yourself win over the preset, so a region that differs a little is easy to describe. For
example, USA/Canada with 3-byte path hashes and a higher transmit power:

```nix
radio = {
  preset = "usa-canada-recommended";
  txPower = 22;           # never part of a preset
};
mesh.pathHashMode = 2;    # 0 = 1-byte, 1 = 2-byte, 2 = 3-byte hashes
```

Not in the list, or want full control? Skip the preset and set `radio.frequency`, `bandwidth`,
`spreadingFactor` and `codingRate` yourself (all four are required then). Check your local regulations for
frequency and power. `radio-presets.json` is a copy of upstream's file, see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## MQTT

MQTT reporting is off unless you set `mqtt.iataCode`. It publishes what your repeater hears to the brokers you
list, so choose them deliberately. Use a bundled network preset, your own broker, or both:

```nix
mqtt = {
  iataCode = "AMS";                     # your nearest airport code
  owner = "<your companion's public key>";   # optional
  brokers = [
    { preset = "letsmesh"; }            # bundled: chimesh, letsmesh, meshat-se, meshcore-ca, meshmapper, waev
    {
      name = "my-broker";
      enabled = true;
      host = "mqtt.example.org";
      port = 8883;
      transport = "tcp";
      tls.enabled = true;
    }
  ];
};
```

Your network's own guide will say which preset or broker to use. Broker passwords do not belong here, because
this part of the configuration ends up in the Nix store.

## Companions and room servers

```nix
services.openhop-repeater = {
  companions."My Companion" = {
    identityKeyFile = "/var/lib/openhop-secrets/companion-key";
    bindAddress = "0.0.0.0";   # defaults to 127.0.0.1: the port has no authentication
    port = 5000;
    openFirewall = true;
  };
  roomServers."Test Room" = {
    identityKeyFile = "/var/lib/openhop-secrets/room-key";
    adminPasswordFile = "/var/lib/openhop-secrets/room-admin";
  };
};
```

## All options

[docs/options.md](docs/options.md) lists every option with its type, default and description. It is generated
from the module, and a check keeps it up to date.

## Updating to a new openHop release

1. In `package.nix`, bump `version` for `openhop-repeater`, and the `openhop-core` version if upstream's
   `pyproject.toml` pins a new one.
2. Get the new hash: `nix store prefetch-file --unpack https://github.com/openhop-dev/openhop_repeater/archive/refs/tags/<version>.tar.gz`
3. Run `scripts/update-generated.sh`. It refreshes the radio presets from the new version's source and
   regenerates `docs/options.md`.
4. `nix flake check`. The `presets-in-sync` and `docs-in-sync` checks fail if step 3 was forgotten. A new upstream release can
   rename config keys, so read the release notes.

## Development

```
nix flake check        # package, rendered config, presets, docs, key converter, start-up script, assertions
nix fmt                # nixfmt
```

The checks need a Linux builder but not KVM. They cover the generated config, the radio presets, the secret
handling at start-up, the key converter (against openhop_core's own key handling), and the configuration
mistakes the module rejects. They do not start the real daemon or talk to
hardware.

## License and AI disclosure

MIT, see [LICENSE.md](LICENSE.md), the same license as openHop Repeater and openhop_core, which this packages.

This project was written largely by an AI assistant (Claude) working with its author. See
[AI-DISCLOSURE.md](AI-DISCLOSURE.md) for what that means, and for what has and has not been tested.
