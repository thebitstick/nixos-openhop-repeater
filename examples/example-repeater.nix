# Example NixOS module: a repeater with a radio preset, MQTT, a companion and a test room server.
#
# Secrets are read from files at runtime and never enter the Nix store. Create them once on the host
# (or provision them with sops-nix / agenix), for example:
#   install -d -m700 /var/lib/openhop-secrets
#   openssl rand -hex 32 | install -m600 /dev/stdin /var/lib/openhop-secrets/companion-key
{
  services.openhop-repeater = {
    enable = true;
    openFirewall = true; # web dashboard on port 8000

    repeater = {
      name = "EXAMPLE-REPEATER";
      latitude = 52.3676;
      longitude = 4.9041;
      ownerInfo = "Contact: example@example.org";
      security = {
        adminPasswordFile = "/var/lib/openhop-secrets/admin";
        jwtSecretFile = "/var/lib/openhop-secrets/jwt";
      };
    };

    # Pick your region's preset (see the option's documentation for the full list). Any
    # radio.* setting you add next to it replaces the preset's value.
    radio = {
      preset = "netherlands";
      txPower = 14; # not part of a preset; check your local rules and your hardware

      # Your radio hardware, for example an openHop Modem on USB:
      type = "modem_usb";
      modemUsb.port = "/dev/serial/by-id/usb-REPLACE-ME";
    };

    # MQTT reporting is optional. Use a bundled network preset and/or your own broker.
    mqtt = {
      iataCode = "AMS";
      brokers = [
        { preset = "letsmesh"; }
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

    # Virtual companion: connect a MeshCore client to <bindAddress>:<port>.
    companions."EXAMPLE-COMPANION" = {
      identityKeyFile = "/var/lib/openhop-secrets/companion-key";
      bindAddress = "0.0.0.0"; # the default is 127.0.0.1
      port = 5000;
      openFirewall = true;
    };

    # Test room server.
    roomServers."ExampleRoom" = {
      nodeName = "EXAMPLE-ROOM";
      identityKeyFile = "/var/lib/openhop-secrets/room-key";
      adminPasswordFile = "/var/lib/openhop-secrets/room-admin";
      guestPasswordFile = "/var/lib/openhop-secrets/room-guest";
    };
  };
}
