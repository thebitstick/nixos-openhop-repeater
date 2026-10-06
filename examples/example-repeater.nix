# Secrets are read from files at runtime and never enter the Nix store, for example:
#   openssl rand -hex 32 | install -m600 /dev/stdin /var/lib/openhop-secrets/companion-key
{
  services.openhop-repeater = {
    enable = true;
    openFirewall = true;

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

    radio = {
      preset = "netherlands";
      txPower = 14;
      type = "modem_usb";
      modemUsb.port = "/dev/serial/by-id/usb-REPLACE-ME";
    };

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

    companions."EXAMPLE-COMPANION" = {
      identityKeyFile = "/var/lib/openhop-secrets/companion-key";
      bindAddress = "0.0.0.0";
      port = 5000;
      openFirewall = true;
    };

    roomServers."ExampleRoom" = {
      nodeName = "EXAMPLE-ROOM";
      identityKeyFile = "/var/lib/openhop-secrets/room-key";
      adminPasswordFile = "/var/lib/openhop-secrets/room-admin";
      guestPasswordFile = "/var/lib/openhop-secrets/room-guest";
    };
  };
}
