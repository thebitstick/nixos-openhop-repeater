# nixos-openhop-repeater

NixOS package + module for [openHop Repeater](https://github.com/openhop-dev/openhop_repeater).

```nix
# flake.nix
inputs.openhop-repeater = {
  url = "github:thebitstick/nixos-openhop-repeater";
  inputs.nixpkgs.follows = "nixpkgs";
};
# ...
modules = [ openhop-repeater.nixosModules.default ./configuration.nix ];
```

```nix
# configuration.nix
{
  services.openhop-repeater = {
    enable = true;
    openFirewall = true;

    repeater = {
      name = "Repeater Name";
      latitude = "41.44663";      # string or float
      longitude = -81.69541;
      security.adminPasswordFile = "/run/secrets/openhop-admin";
    };

    radio = {
      type = "sx1262";            # or sx1262_ch341 | kiss | modem_tcp | modem_usb
      frequency = 910525000;      # Hz; no default, pick your region's
      sx1262 = { cs_pin = 21; reset_pin = 18; busy_pin = 20; irq_pin = 16; };
    };

    # Anything else upstream's config.yaml supports:
    settings.mqtt_brokers = { iata_code = "CLE"; brokers = [ { preset = "letsmesh"; } ]; };
  };
}
```

Notes
- `config.yaml` is regenerated from Nix on every service start into `/var/lib/openhop_repeater/`.
  Changes made in the web UI last until the next restart; put them in Nix to keep them.
- Secrets go through `*File` options (systemd `LoadCredential`), never the Nix store.
- The identity key lives in `/var/lib/openhop_repeater/identity.key`. Back it up.
- On a Raspberry Pi, enable SPI separately (e.g. `hardware.raspberry-pi."4".apply-overlays-dtmerge` / `dtparam=spi=on`).

## ChicagolandMesh profile, companions, room servers

See `examples/example-chicago-repeater.nix` for a full example:

- `chicagolandMesh.enable = true` applies the [ChicagolandMesh](https://chicagolandmesh.org/guides/meshcore/getting-started/configure/)
  recommended setup (910.525 MHz / 62.5 kHz / SF7 / CR5 / 22 dBm, 3-byte path hashes, 4 h advert interval, minimal loop detection (per ChiMesh's openHop guide))
  plus MQTT reporting to LetsMesh and ChiMesh with IATA `ORD`. Turn MQTT off with `chicagolandMesh.mqtt = false`.
- `companions.<name>` defines virtual companions: `nodeName`, `identityKeyFile`, `bindAddress`, `port`.
- `roomServers.<name>` defines room servers: `nodeName`, `identityKeyFile`, location, advert intervals, password files.
- Identity keys are hex files (`openssl rand -hex 32`), kept out of the Nix store, and must be unique per identity.
