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
      chicagolandMesh.enable = true;
      repeater = {
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
        t '.radio.frequency == 910525000 and .radio.spreading_factor == 7'
        t '.radio_type == "modem_usb" and .modem_usb.port == "/dev/ttyUSB0"'
        t '.mqtt_brokers.iata_code == "ORD"'
        t '.identities.companions[0].name == "Comp 🐧" and .identities.companions[0].settings.tcp_port == 5050'
        t '.identities.room_servers[0].type == "room_server"'
        t 'has("sx1262") | not'
        # secrets must never be rendered into the (world-readable) store
        ! grep -qiE 'identity_key|admin_password|jwt_secret' $j
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
  rejects-missing-frequency = rejects "freq" "radio.frequency must be set" {
    services.openhop-repeater = {
      repeater.name = "x";
      radio.type = "sx1262";
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
