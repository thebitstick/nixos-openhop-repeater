# Checks run by `nix flake check`. None of them need KVM, so they work in plain CI.
{
  pkgs,
  lib ? pkgs.lib,
  module,
  nixosSystem,
  package,
}:

let
  system = pkgs.stdenv.hostPlatform.system;

  eval =
    extra:
    nixosSystem {
      inherit system;
      modules = [
        module
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "x";
            fsType = "ext4";
          };
          system.stateVersion = "25.11";
          services.openhop-repeater.enable = true;
        }
        extra
      ];
    };

  # A configuration using most features.
  full = eval {
    services.openhop-repeater = {
      mesh = {
        pathHashMode = 2;
        loopDetect = "minimal";
      };
      mqtt = {
        iataCode = "ORD";
        owner = "AABBCC";
        brokers = [
          { preset = "letsmesh"; }
          {
            name = "mine";
            host = "mqtt.example.org";
          }
        ];
      };
      repeater = {
        sendAdvertIntervalHours = 4;
        name = "TEST-REPEATER";
        latitude = "41.8781";
        longitude = -87.6298;
        identityKeyFile = "/x/identity";
        identityFile = "/tmp/state/identity.key";
        security = {
          adminPasswordFile = "/x/admin";
          jwtSecretFile = "/x/jwt";
        };
      };
      radio = {
        type = "modem_usb";
        modemUsb.port = "/dev/ttyUSB0";
        preset = "usa-canada-recommended";
        txPower = 22;
      };
      companions."Comp 🐧" = {
        identityKeyFile = "/x/comp";
        port = 5050;
        openFirewall = true;
      };
      roomServers.Room = {
        identityKeyFile = "/x/room";
        adminPasswordFile = "/x/room-admin";
      };
    };
  };

  rendered-of = extra: (eval extra).config.services.openhop-repeater.renderedSettings;
  presetOnly = rendered-of {
    services.openhop-repeater = {
      repeater.name = "x";
      radio = {
        type = "modem_usb";
        modemUsb.port = "/dev/ttyUSB0";
        preset = "hungary";
      };
    };
  };
  presetOverridden = rendered-of {
    services.openhop-repeater = {
      repeater.name = "x";
      mesh.pathHashMode = 2;
      radio = {
        type = "modem_usb";
        modemUsb.port = "/dev/ttyUSB0";
        preset = "hungary";
        frequency = 869000000;
        codingRate = 8;
      };
    };
  };
  explicitOnly = rendered-of {
    services.openhop-repeater = {
      repeater.name = "x";
      radio = {
        type = "modem_usb";
        modemUsb.port = "/dev/ttyUSB0";
        frequency = 433650000;
        bandwidth = 125000;
        spreadingFactor = 9;
        codingRate = 6;
      };
    };
  };
  failing = cfg: map (a: a.message) (lib.filter (a: !a.assertion) cfg.config.assertions);

  # Passes only if the configuration trips an assertion containing `needle`.
  rejects =
    name: needle: extra:
    let
      msgs = failing (eval extra);
    in
    assert lib.assertMsg (lib.any (
      m: lib.hasInfix needle m
    ) msgs) "${name}: expected assertion '${needle}', got ${builtins.toJSON msgs}";
    pkgs.runCommand "openhop-repeater-rejects-${name}" { } "touch $out";

  rendered = pkgs.writeText "rendered.json" (
    builtins.toJSON full.config.services.openhop-repeater.renderedSettings
  );
  json = name: value: pkgs.writeText "${name}.json" (builtins.toJSON value);
  svc = full.config.systemd.services.openhop-repeater.serviceConfig;
in
{
  inherit package;

  # The rendered config has the values we expect.
  rendered-config =
    pkgs.runCommand "openhop-repeater-rendered-config"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        j=${rendered}
        t() { jq -e "$1" $j >/dev/null || { echo "FAILED: $1"; jq . $j; exit 1; }; }
        t '.repeater.node_name == "TEST-REPEATER"'
        t '.repeater.latitude == 41.8781'
        t '.repeater.send_advert_interval_hours == 4'
        t '.mesh.path_hash_mode == 2 and .mesh.loop_detect == "minimal"'
        t '.radio == {frequency: 910525000, bandwidth: 62500, spreading_factor: 7, coding_rate: 5, tx_power: 22, preamble_length: 32}'
        t '.radio_type == "modem_usb" and .modem_usb.port == "/dev/ttyUSB0"'
        t '.mqtt_brokers.iata_code == "ORD" and .mqtt_brokers.owner == "AABBCC"'
        t '.mqtt_brokers.brokers | length == 2'
        t '.identities.companions[0].name == "Comp 🐧" and .identities.companions[0].settings.tcp_port == 5050'
        t '.identities.room_servers[0].type == "room_server"'
        t 'has("sx1262") | not'
        # secrets must never be rendered into the (world-readable) store
        ! grep -qiE 'identity_key|admin_password|jwt_secret' $j
        touch $out
      '';

  # Presets expand to the right values, and your own settings win over them.
  radio-presets =
    pkgs.runCommand "openhop-repeater-radio-presets" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        t() { jq -e "$2" $1 >/dev/null || { echo "FAILED: $2"; jq . $1; exit 1; }; }
        # preset only; Hungary's preset also sets 2-byte path hashes (mode 1)
        t ${json "preset" presetOnly} '.radio.frequency == 869618000 and .radio.bandwidth == 62500 and .radio.spreading_factor == 7 and .radio.coding_rate == 5'
        t ${json "preset" presetOnly} '.mesh.path_hash_mode == 1'
        # explicit settings replace the preset's, the rest is kept; an explicit hash mode wins
        t ${json "override" presetOverridden} '.radio.frequency == 869000000 and .radio.coding_rate == 8 and .radio.spreading_factor == 7'
        t ${json "override" presetOverridden} '.mesh.path_hash_mode == 2'
        # no preset at all: explicit values are used and no hash mode is invented
        t ${json "explicit" explicitOnly} '.radio.frequency == 433650000 and .radio.bandwidth == 125000 and .radio.spreading_factor == 9 and .radio.coding_rate == 6'
        t ${json "explicit" explicitOnly} 'has("mesh") | not'
        touch $out
      '';

  # The vendored preset list is still identical to upstream's at the version we package.
  presets-in-sync = pkgs.runCommand "openhop-repeater-presets-in-sync" { } ''
    cmp ${package.src}/radio-presets.json ${../radio-presets.json} \
      || { echo "radio-presets.json differs from upstream; see 'Updating' in the README"; exit 1; }
    touch $out
  '';

  # Runs the real start-up script with fake secrets and checks what it writes.
  prepare-script =
    pkgs.runCommand "openhop-repeater-prepare-script"
      {
        nativeBuildInputs = [ pkgs.jq ];
        pre = svc.ExecStartPre;
        passthru = { };
      }
      ''
        mkdir -p $out creds /tmp/state
        set -- $pre
        script=$1; store=$2; manifest=$3; dst=$4
        for c in $(jq -r '.secrets[].cred' $manifest); do printf 'VALUE-%s\n' "$c" > creds/$c; done
        printf 'IDENTITY-BYTES' > creds/identity-key
        export CREDENTIALS_DIRECTORY=$PWD/creds
        $script $store $manifest $out/config.yaml

        [ "$(cat /tmp/state/identity.key)" = "IDENTITY-BYTES" ] || { echo "identity key not installed verbatim"; exit 1; }
        [ "$(stat -c %a /tmp/state/identity.key)" = 600 ] || { echo "identity key must be 0600"; exit 1; }
        [ "$(stat -c %a $out/config.yaml)" = 600 ] || { echo "config must be 0600"; exit 1; }
        grep -q 'VALUE-secret-0' $out/config.yaml
        grep -q 'identity_key' $out/config.yaml
        grep -q 'admin_password' $out/config.yaml
      '';

  # Mistakes are reported clearly instead of producing a broken service.
  rejects-incomplete-radio = rejects "radio" "set radio.preset, or set radio.frequency" {
    services.openhop-repeater = {
      repeater.name = "x";
      radio = {
        type = "sx1262";
        frequency = 910525000; # a frequency alone is not enough without a preset
      };
    };
  };
  rejects-modem-without-port = rejects "port" "modemUsb.port" {
    services.openhop-repeater = {
      repeater.name = "x";
      radio = {
        type = "modem_usb";
        frequency = 910525000;
      };
    };
  };
  rejects-duplicate-names = rejects "names" "must be unique" {
    services.openhop-repeater = {
      repeater.name = "x";
      companions.A.identityKeyFile = "/x/a";
      roomServers.A.identityKeyFile = "/x/b";
    };
  };
  rejects-port-clash = rejects "ports" "ports must all be different" {
    services.openhop-repeater = {
      repeater.name = "x";
      companions.A = {
        identityKeyFile = "/x/a";
        port = 8000;
      };
    };
  };
  rejects-bad-latitude = rejects "lat" "latitude must be between" {
    services.openhop-repeater = {
      repeater = {
        name = "x";
        latitude = 91.0;
      };
    };
  };
}
