{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkMerge
    types
    literalExpression
    optional
    optionals
    optionalAttrs
    recursiveUpdate
    filterAttrsRecursive
    mapAttrsToList
    filterAttrs
    imap0
    concatLists
    attrNames
    ;

  cfg = config.services.openhop-repeater;
  yaml = pkgs.formats.yaml { };

  # Directory name below /var/lib; matches the paths upstream uses by default.
  stateName = "openhop_repeater";
  stateDir = "/var/lib/${stateName}";
  runtimeConfig = "${stateDir}/config.yaml";

  # Accept "41.44663" as well as 41.44663; the daemon wants a float.
  coordinate = types.coercedTo types.str builtins.fromJSON types.float;

  radioPresets = import ./presets.nix { inherit lib; };
  preset = if cfg.radio.preset == null then null else radioPresets.${cfg.radio.preset};

  # An explicit setting wins over the preset, which wins over nothing.
  fromPreset = name: if preset == null then null else preset.${name};
  effective = explicit: name: if explicit != null then explicit else fromPreset name;
  radio = {
    frequency = effective cfg.radio.frequency "frequency";
    bandwidth = effective cfg.radio.bandwidth "bandwidth";
    spreadingFactor = effective cfg.radio.spreadingFactor "spreadingFactor";
    codingRate = effective cfg.radio.codingRate "codingRate";
  };
  pathHashMode = effective cfg.mesh.pathHashMode "pathHashMode";

  meshSettings = dropNulls {
    path_hash_mode = pathHashMode;
    loop_detect = cfg.mesh.loopDetect;
    default_region = cfg.mesh.defaultRegion;
  };

  # Secrets are left out of these entries; see `injections` below.
  companionEntries = mapAttrsToList (name: c: {
    inherit name;
    settings = dropNulls (
      {
        node_name = c.nodeName;
        bind_address = c.bindAddress;
        tcp_port = c.port;
        tcp_timeout = c.tcpTimeout;
      }
      // c.settings
    );
  }) cfg.companions;

  roomServerEntries = mapAttrsToList (name: r: {
    inherit name;
    type = "room_server";
    settings = dropNulls (
      {
        node_name = r.nodeName;
        latitude = r.latitude;
        longitude = r.longitude;
        flood_advert_interval_hours = r.floodAdvertIntervalHours;
        direct_advert_interval_hours = r.directAdvertIntervalHours;
      }
      // r.settings
    );
  }) cfg.roomServers;

  radioTypeUsesSpi = cfg.radio.type == "sx1262";
  radioTypeUsesCh341 = cfg.radio.type == "sx1262_ch341";

  dropNulls = filterAttrsRecursive (_: v: v != null);

  generated = {
    repeater = {
      node_name = cfg.repeater.name;
      latitude = cfg.repeater.latitude;
      longitude = cfg.repeater.longitude;
      mode = cfg.repeater.mode;
      owner_info = cfg.repeater.ownerInfo;
      identity_file = cfg.repeater.identityFile;
      send_advert_interval_hours = cfg.repeater.sendAdvertIntervalHours;
      direct_advert_interval_hours = cfg.repeater.directAdvertIntervalHours;
      allow_discovery = cfg.repeater.allowDiscovery;
      security = {
        max_clients = cfg.repeater.security.maxClients;
        allow_read_only = cfg.repeater.security.allowReadOnly;
        jwt_expiry_minutes = cfg.repeater.security.jwtExpiryMinutes;
      };
    };

    radio_type = cfg.radio.type;
    radio = {
      frequency = radio.frequency;
      tx_power = cfg.radio.txPower;
      bandwidth = radio.bandwidth;
      spreading_factor = radio.spreadingFactor;
      coding_rate = radio.codingRate;
      preamble_length = cfg.radio.preambleLength;
    };

    storage.storage_dir = stateDir;
    http = {
      inherit (cfg.http) host port;
      enabled = cfg.http.enable;
    };
    logging.level = cfg.logLevel;

    gps = {
      enabled = cfg.gps.enable;
      device = cfg.gps.device;
    };

    # Runtime `pip install` cannot work on NixOS.
    sensors.auto_install_packages = false;
  }
  // optionalAttrs (meshSettings != { }) { mesh = meshSettings; }
  // optionalAttrs (cfg.mqtt.iataCode != null) {
    mqtt_brokers = {
      iata_code = cfg.mqtt.iataCode;
      owner = cfg.mqtt.owner;
      brokers = cfg.mqtt.brokers;
    };
  }
  // optionalAttrs (cfg.companions != { } || cfg.roomServers != { }) {
    identities = {
      companions = companionEntries;
      room_servers = roomServerEntries;
    };
  }
  // optionalAttrs radioTypeUsesSpi {
    sx1262 = {
      bus_id = 0;
      cs_id = 0;
      cs_pin = 21;
      reset_pin = 18;
      busy_pin = 20;
      irq_pin = 16;
      txen_pin = -1;
      rxen_pin = -1;
    }
    // cfg.radio.sx1262;
  }
  // optionalAttrs radioTypeUsesCh341 {
    sx1262 = {
      bus_id = 0;
      cs_id = 0;
      cs_pin = 0;
      reset_pin = 1;
      busy_pin = 2;
      irq_pin = 3;
      txen_pin = -1;
      rxen_pin = -1;
    }
    // cfg.radio.sx1262;
    ch341 = cfg.radio.ch341;
  }
  // optionalAttrs (cfg.radio.type == "kiss") { kiss = cfg.radio.kiss; }
  // optionalAttrs (cfg.radio.type == "modem_tcp") { modem_tcp = cfg.radio.modemTcp; }
  // optionalAttrs (cfg.radio.type == "modem_usb") { modem_usb = cfg.radio.modemUsb; };

  # `settings` is applied last so anything upstream supports can be set from Nix.
  finalSettings = dropNulls (recursiveUpdate generated cfg.settings);
  storeConfig = yaml.generate "openhop-repeater-config.yaml" finalSettings;

  # Every secret to merge into the config at start. `entry` is null for the
  # repeater's own security block, otherwise the identity it belongs to.
  injections = lib.filter (i: i.file != null) (
    [
      {
        entry = null;
        path = [ "admin_password" ];
        file = cfg.repeater.security.adminPasswordFile;
      }
      {
        entry = null;
        path = [ "guest_password" ];
        file = cfg.repeater.security.guestPasswordFile;
      }
      {
        entry = null;
        path = [ "jwt_secret" ];
        file = cfg.repeater.security.jwtSecretFile;
      }
    ]
    ++ mapAttrsToList (name: c: {
      entry = {
        section = "companions";
        inherit name;
      };
      path = [ "identity_key" ];
      file = c.identityKeyFile;
    }) cfg.companions
    ++ concatLists (
      mapAttrsToList (
        name: r:
        let
          entry = {
            section = "room_servers";
            inherit name;
          };
        in
        [
          {
            inherit entry;
            path = [ "identity_key" ];
            file = r.identityKeyFile;
          }
          {
            inherit entry;
            path = [
              "settings"
              "admin_password"
            ];
            file = r.adminPasswordFile;
          }
          {
            inherit entry;
            path = [
              "settings"
              "guest_password"
            ];
            file = r.guestPasswordFile;
          }
        ]
      ) cfg.roomServers
    )
  );
  numbered = imap0 (n: i: i // { cred = "secret-${toString n}"; }) injections;

  manifest = pkgs.writeText "openhop-repeater-secrets.json" (
    builtins.toJSON {
      secrets = map (i: { inherit (i) entry path cred; }) numbered;
      identity =
        if cfg.repeater.identityKeyFile == null then
          null
        else
          {
            cred = "identity-key";
            dest = cfg.repeater.identityFile;
          };
    }
  );

  # Merges secrets (never placed in the Nix store) into the config and writes it
  # to the state directory, where the daemon expects a writable config file.
  prepareConfig =
    pkgs.writers.writePython3 "openhop-repeater-prepare-config"
      {
        libraries = [ pkgs.python3Packages.pyyaml ];
        flakeIgnore = [
          "E"
          "W"
        ];
      }
      ''
        import json
        import os
        import sys

        import yaml

        src, manifest, dst = sys.argv[1], sys.argv[2], sys.argv[3]
        with open(src) as f:
            cfg = yaml.safe_load(f)
        with open(manifest) as f:
            manifest_data = json.load(f)
        injections = manifest_data["secrets"]

        creds = os.environ["CREDENTIALS_DIRECTORY"]
        for inj in injections:
            with open(os.path.join(creds, inj["cred"])) as f:
                value = f.read().strip()
            entry = inj["entry"]
            if entry is None:
                target = cfg.setdefault("repeater", {}).setdefault("security", {})
            else:
                items = cfg["identities"][entry["section"]]
                target = next(e for e in items if e["name"] == entry["name"])
            *parents, leaf = inj["path"]
            for key in parents:
                target = target.setdefault(key, {})
            target[leaf] = value

        ident = manifest_data["identity"]
        if ident is not None:
            with open(os.path.join(creds, ident["cred"]), "rb") as f:
                data = f.read()
            tmp = ident["dest"] + ".tmp"
            fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "wb") as f:
                f.write(data)
            os.replace(tmp, ident["dest"])

        tmp = dst + ".tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            yaml.safe_dump(cfg, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        os.replace(tmp, dst)
      '';

  credentials =
    map (i: "${i.cred}:${i.file}") numbered
    ++ optional (cfg.repeater.identityKeyFile != null) "identity-key:${cfg.repeater.identityKeyFile}";
in
{
  options.services.openhop-repeater = {
    enable = mkEnableOption "the openHop Repeater MeshCore daemon";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = literalExpression "pkgs.callPackage ./package.nix { }";
      description = ''
        The openhop-repeater package to run. The default is built from this repository
        with your nixpkgs; set it to `pkgs.openhop-repeater` if you use the overlay.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "openhop-repeater";
      description = "Service user.";
    };
    group = mkOption {
      type = types.str;
      default = "openhop-repeater";
      description = "Service group.";
    };

    extraGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "i2c" ];
      description = ''
        Extra groups for the service user, beyond those the module adds for the
        selected radio (`dialout`, `plugdev`, `gpio`, `spi`).
      '';
    };

    openFirewall = mkEnableOption "opening the web dashboard port in the firewall";

    logLevel = mkOption {
      type = types.enum [
        "TRACE"
        "DEBUG"
        "INFO"
        "WARNING"
        "ERROR"
      ];
      default = "INFO";
      description = "Daemon log level.";
    };

    repeater = {
      name = mkOption {
        type = types.str;
        example = "Hilltop Repeater";
        description = "Node name advertised on the mesh (`repeater.node_name`).";
      };

      latitude = mkOption {
        type = coordinate;
        default = 0.0;
        example = "41.44663";
        description = "Latitude in decimal degrees (-90 to 90). Strings are accepted and converted.";
      };

      longitude = mkOption {
        type = coordinate;
        default = 0.0;
        example = "-81.69541";
        description = "Longitude in decimal degrees (-180 to 180). Strings are accepted and converted.";
      };

      mode = mkOption {
        type = types.enum [
          "forward"
          "monitor"
          "no_tx"
        ];
        default = "forward";
        description = "`forward` repeats packets, `monitor` doesn't repeat, `no_tx` disables all transmit.";
      };

      ownerInfo = mkOption {
        type = types.str;
        default = "";
        description = "Owner info shown to clients that request it.";
      };

      identityKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/var/lib/openhop-secrets/identity.key";
        description = ''
          File holding the repeater's identity key, in the format the daemon writes
          (an existing `identity.key`). It is copied to `identityFile` at every start, so
          the node keeps its identity and never generates a new one. If null, the daemon
          creates `identityFile` on first start. Kept out of the Nix store.
        '';
      };

      identityFile = mkOption {
        type = types.str;
        default = "${stateDir}/identity.key";
        description = ''
          Path to the node's identity key. Created on first start if missing, so the
          node keeps the same identity across rebuilds. Back this file up.
        '';
      };

      sendAdvertIntervalHours = mkOption {
        type = types.ints.unsigned;
        default = 10;
        description = "Flood advert interval in hours; 0 disables automatic adverts.";
      };

      directAdvertIntervalHours = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = "Additional zero-hop advert interval in hours; 0 disables.";
      };

      allowDiscovery = mkOption {
        type = types.bool;
        default = true;
        description = "Respond to discovery requests from other nodes.";
      };

      security = {
        adminPasswordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/run/secrets/openhop-admin-password";
          description = "File containing the admin password. Kept out of the Nix store.";
        };
        guestPasswordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File containing the guest password. Kept out of the Nix store.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            File containing the JWT signing secret (e.g. `openssl rand -hex 32`).
            If unset the daemon generates one.
          '';
        };
        maxClients = mkOption {
          type = types.ints.positive;
          default = 5;
          description = "Max authenticated clients.";
        };
        allowReadOnly = mkOption {
          type = types.bool;
          default = false;
          description = "Allow read-only access without a password.";
        };
        jwtExpiryMinutes = mkOption {
          type = types.ints.positive;
          default = 60;
          description = "Web login lifetime.";
        };
      };
    };

    radio = {
      type = mkOption {
        type = types.nullOr (
          types.enum [
            "sx1262"
            "sx1262_ch341"
            "kiss"
            "modem_tcp"
            "modem_usb"
          ]
        );
        default = null;
        description = ''
          Radio backend. `sx1262` is a Linux SPI/GPIO radio (e.g. Raspberry Pi HAT),
          `sx1262_ch341` is CH341 USB-to-SPI, `kiss` a serial KISS modem, and
          `modem_tcp` / `modem_usb` an openHop Modem. `null` starts the daemon
          without any RF I/O.
        '';
      };

      preset = mkOption {
        type = types.nullOr (types.enum (lib.attrNames radioPresets));
        default = null;
        example = "eu-uk-narrow";
        description = ''
          A named set of regional radio settings (frequency, bandwidth, spreading factor, coding
          rate, and a path hash size where the region defines one). Any of those you also set
          yourself, such as `radio.frequency`, replaces the preset's value. `radio.txPower` is
          not part of a preset. The presets are upstream openHop's list:

        ''
        + lib.concatMapStringsSep "\n" (
          name: "- `${name}`: ${radioPresets.${name}.title}, ${radioPresets.${name}.description}"
        ) (lib.attrNames radioPresets);
      };

      frequency = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        example = 910525000;
        description = "Frequency in Hz. Overrides `radio.preset`. Without a preset you must set this and the three settings below.";
      };
      txPower = mkOption {
        type = types.int;
        default = 14;
        description = "TX power in dBm.";
      };
      bandwidth = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        example = 62500;
        description = "Bandwidth in Hz. Overrides `radio.preset`.";
      };
      spreadingFactor = mkOption {
        type = types.nullOr (types.ints.between 5 12);
        default = null;
        example = 7;
        description = "LoRa spreading factor. Overrides `radio.preset`.";
      };
      codingRate = mkOption {
        type = types.nullOr (types.ints.between 5 8);
        default = null;
        example = 5;
        description = "LoRa coding rate denominator (5-8). Overrides `radio.preset`.";
      };
      preambleLength = mkOption {
        type = types.ints.positive;
        default = 32;
        description = "Preamble length in symbols.";
      };

      sx1262 = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        example = {
          cs_pin = 21;
          reset_pin = 18;
          busy_pin = 20;
          irq_pin = 16;
          use_dio3_tcxo = true;
        };
        description = ''
          Overrides for the `sx1262` hardware section (BCM GPIO numbers for `sx1262`,
          CH341 GPIO 0-7 for `sx1262_ch341`). Unset keys use upstream's defaults.
        '';
      };
      ch341 = mkOption {
        type = types.attrsOf types.anything;
        default = {
          vid = 6790;
          pid = 21778;
        };
        description = "`ch341` section (USB vid/pid, optional bus/address/serial_number).";
      };
      kiss = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        example = {
          port = "/dev/ttyUSB0";
          baud_rate = 9600;
        };
        description = "`kiss` section, used when `radio.type = \"kiss\"`.";
      };
      modemTcp = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        example = {
          host = "openhop-modem.local";
          port = 5055;
        };
        description = "`modem_tcp` section, used when `radio.type = \"modem_tcp\"`.";
      };
      modemUsb = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        example = {
          port = "/dev/ttyACM0";
          baudrate = 921600;
        };
        description = "`modem_usb` section, used when `radio.type = \"modem_usb\"`.";
      };
    };

    http = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the web dashboard and API.";
      };
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Listen address.";
      };
      port = mkOption {
        type = types.port;
        default = 8000;
        description = "Listen port.";
      };
    };

    gps = {
      enable = mkEnableOption "reading a local GPS receiver (also lets the daemon set the system clock)";
      device = mkOption {
        type = types.str;
        default = "/dev/serial0";
        description = "Serial device for the GPS module.";
      };
    };

    mesh = {
      pathHashMode = mkOption {
        type = types.nullOr (
          types.enum [
            0
            1
            2
          ]
        );
        default = null;
        description = ''
          Per-hop path hash size: 0 = 1 byte (legacy), 1 = 2 bytes, 2 = 3 bytes.
          Must match the rest of your mesh. If null, the value from `radio.preset` is used when the
          preset defines one, otherwise the upstream default applies.
        '';
      };
      loopDetect = mkOption {
        type = types.nullOr (
          types.enum [
            "off"
            "minimal"
            "moderate"
            "strict"
          ]
        );
        default = null;
        description = "Flood loop detection mode. Null leaves the upstream default.";
      };
      defaultRegion = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default flood scope for locally originated flood adverts.";
      };
    };

    mqtt = {
      iataCode = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "ORD";
        description = "IATA airport code identifying your area. Setting it enables the `mqtt_brokers` section.";
      };
      owner = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Public key of your companion device, which links the repeater to it on MQTT analyzers.
          A public key, not a secret.
        '';
      };
      brokers = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = [ ];
        example = literalExpression ''
          [
            { preset = "letsmesh"; }
            {
              name = "my-broker";
              enabled = true;
              host = "mqtt.example.org";
              port = 8883;
              transport = "tcp";
              username = "repeater";
              tls.enabled = true;
            }
          ]
        '';
        description = ''
          Broker list, in upstream's format. An entry can be a bundled network preset such as
          `{ preset = "letsmesh"; }` (bundled: `chimesh`, `letsmesh`, `meshat-se`, `meshcore-ca`,
          `meshmapper`, `waev`), or a full broker definition. Do not put a broker password here:
          it would end up in the Nix store.
        '';
      };
    };

    companions = mkOption {
      default = { };
      description = ''
        Virtual companion identities. Each one exposes the MeshCore companion
        protocol over TCP so standard clients can connect to `bindAddress:port`
        (one client at a time). The attribute name is the identity's `name`.
      '';
      type = types.attrsOf (
        types.submodule (
          { name, ... }: {
            options = {
              nodeName = mkOption {
                type = types.strMatching ".{1,31}";
                default = name;
                description = "Name the companion presents on the mesh (max 31 characters).";
              };
              identityKeyFile = mkOption {
                type = types.path;
                example = "/run/secrets/openhop-companion-key";
                description = ''
                  File holding the identity key as hex: 64 characters (32-byte seed) or 128
                  (MeshCore firmware key). Must differ from every other identity on the node.
                  Generate a new one with `openssl rand -hex 32`.
                '';
              };
              bindAddress = mkOption {
                type = types.str;
                default = "127.0.0.1";
                example = "0.0.0.0";
                description = ''
                  Address the TCP server binds to. Defaults to localhost because the companion
                  port has no authentication; use `0.0.0.0` only on a trusted network.
                '';
              };
              port = mkOption {
                type = types.port;
                default = 5000;
                description = "TCP port.";
              };
              tcpTimeout = mkOption {
                type = types.nullOr types.ints.unsigned;
                default = null;
                description = "Client idle timeout in seconds; 0 disables. Null uses upstream's default (120).";
              };
              openFirewall = mkEnableOption "opening this companion's TCP port in the firewall";
              settings = mkOption {
                type = types.attrsOf types.anything;
                default = { };
                description = "Extra keys for this companion's `settings` block.";
              };
            };
          }
        )
      );
    };

    roomServers = mkOption {
      default = { };
      description = ''
        Room server identities. Each acts as a separate logical node on the mesh.
        The attribute name is the identity's `name`.
      '';
      type = types.attrsOf (
        types.submodule (
          { name, ... }: {
            options = {
              nodeName = mkOption {
                type = types.str;
                default = name;
                description = "Name the room presents on the mesh.";
              };
              identityKeyFile = mkOption {
                type = types.path;
                example = "/run/secrets/openhop-room-key";
                description = "File holding the room's identity key as hex (see `companions.<name>.identityKeyFile`).";
              };
              latitude = mkOption {
                type = types.nullOr coordinate;
                default = null;
                description = "Room latitude.";
              };
              longitude = mkOption {
                type = types.nullOr coordinate;
                default = null;
                description = "Room longitude.";
              };
              floodAdvertIntervalHours = mkOption {
                type = types.nullOr types.ints.unsigned;
                default = null;
                description = "Flood advert interval in hours.";
              };
              directAdvertIntervalHours = mkOption {
                type = types.nullOr types.ints.unsigned;
                default = null;
                description = "Zero-hop advert interval in hours.";
              };
              adminPasswordFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "File with the room's admin password.";
              };
              guestPasswordFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "File with the room's guest password.";
              };
              settings = mkOption {
                type = types.attrsOf types.anything;
                default = { };
                description = "Extra keys for this room's `settings` block.";
              };
            };
          }
        )
      );
    };

    renderedSettings = mkOption {
      type = yaml.type;
      readOnly = true;
      default = finalSettings;
      defaultText = lib.literalMD "the generated configuration";
      description = ''
        The final config (minus secrets) written to `config.yaml`. Read-only; inspect with
        `nix eval .#nixosConfigurations.<host>.config.services.openhop-repeater.renderedSettings`.
      '';
    };

    settings = mkOption {
      type = yaml.type;
      default = { };
      example = literalExpression ''
        {
          mqtt_brokers = {
            iata_code = "CLE";
            brokers = [ { preset = "letsmesh"; } ];
          };
          mesh.loop_detect = "moderate";
        }
      '';
      description = ''
        Free-form settings merged over everything above, using upstream's
        `config.yaml` keys (see `config.yaml.example` in the openhop_repeater repo).
        Values of `null` are dropped. Do not put secrets here: they end up in the Nix store.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.radio.type == null || lib.all (v: v != null) (lib.attrValues radio);
          message = "services.openhop-repeater.radio: set radio.preset, or set radio.frequency, bandwidth, spreadingFactor and codingRate, when a radio type is configured.";
        }
        {
          assertion = cfg.radio.type != "modem_usb" || cfg.radio.modemUsb ? port;
          message = "services.openhop-repeater.radio.modemUsb.port must be set when radio.type is \"modem_usb\".";
        }
        {
          assertion = cfg.radio.type != "kiss" || cfg.radio.kiss ? port;
          message = "services.openhop-repeater.radio.kiss.port must be set when radio.type is \"kiss\".";
        }
        {
          assertion = cfg.radio.type != "modem_tcp" || cfg.radio.modemTcp ? host;
          message = "services.openhop-repeater.radio.modemTcp.host must be set when radio.type is \"modem_tcp\".";
        }
        {
          assertion =
            lib.intersectLists (attrNames cfg.companions) (attrNames cfg.roomServers) == [ ]
            && !(cfg.companions ? repeater || cfg.roomServers ? repeater);
          message = "services.openhop-repeater: companion and room server names must be unique across both sets and must not be \"repeater\".";
        }
        {
          assertion =
            let
              ports = optional cfg.http.enable cfg.http.port ++ mapAttrsToList (_: c: c.port) cfg.companions;
            in
            lib.unique ports == ports;
          message = "services.openhop-repeater: the HTTP port and companion TCP ports must all be different.";
        }
        {
          assertion = cfg.repeater.latitude >= -90 && cfg.repeater.latitude <= 90;
          message = "services.openhop-repeater.repeater.latitude must be between -90 and 90.";
        }
        {
          assertion = cfg.repeater.longitude >= -180 && cfg.repeater.longitude <= 180;
          message = "services.openhop-repeater.repeater.longitude must be between -180 and 180.";
        }
      ];

      warnings =
        optional (cfg.repeater.security.adminPasswordFile == null && cfg.http.enable)
          "services.openhop-repeater: no admin password set; web dashboard login will not work. Set repeater.security.adminPasswordFile.";

      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = stateDir;
        extraGroups = [
          "dialout"
          "plugdev"
          "gpio"
          "spi"
        ]
        ++ cfg.extraGroups;
      };
      users.groups.${cfg.group} = { };
      users.groups.plugdev = { };
      users.groups.gpio = { };
      users.groups.spi = { };

      services.udev.extraRules = ''
        SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"
        SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="5512", GROUP="plugdev", MODE="0660"
      '';

      networking.firewall.allowedTCPPorts =
        optional cfg.openFirewall cfg.http.port
        ++ mapAttrsToList (_: c: c.port) (filterAttrs (_: c: c.openFirewall) cfg.companions);

      systemd.services.openhop-repeater = {
        description = "openHop Repeater Daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        # Re-render the config whenever the Nix-declared settings change.
        restartTriggers = [
          storeConfig
          manifest
        ];

        environment.HOME = stateDir;

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = stateName;
          StateDirectoryMode = "0750";
          WorkingDirectory = stateDir;
          LoadCredential = credentials;

          ExecStartPre = "${prepareConfig} ${storeConfig} ${manifest} ${runtimeConfig}";
          ExecStart = "${lib.getExe cfg.package} --config ${runtimeConfig}";

          Restart = "on-failure";
          RestartSec = 5;
          TimeoutStopSec = 10;
          MemoryHigh = "256M";
          SyslogIdentifier = "openhop-repeater";

          # GPS time sync needs CAP_SYS_TIME.
          CapabilityBoundingSet = if cfg.gps.enable then [ "CAP_SYS_TIME" ] else [ "" ];
          AmbientCapabilities = optionals cfg.gps.enable [ "CAP_SYS_TIME" ];

          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
        };
      };
    }
  ]);
}
