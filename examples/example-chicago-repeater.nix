# Example NixOS module for a Chicago-area repeater with a companion and a test room server.
#
# Secrets are read from files at runtime and never enter the Nix store. Create them
# once on the host (or provision with sops-nix / agenix), e.g.:
#   install -d -m700 /run/secrets
#   openssl rand -hex 32 | install -m600 /dev/stdin /run/secrets/openhop-companion-key
{
  services.openhop-repeater = {
    enable = true;
    openFirewall = true;

    # ChicagolandMesh recommended setup: radio preset, 3-byte path hashes,
    # advert intervals, and MQTT reporting (IATA "ORD").
    chicagolandMesh.enable = true;

    repeater = {
      name = "ORD-EXAMPLE-REPEATER";
      latitude = 41.8781;
      longitude = -87.6298;
      ownerInfo = "Bluesky: @example.bsky.social";
      security = {
        adminPasswordFile = "/run/secrets/openhop-admin";
        jwtSecretFile = "/run/secrets/openhop-jwt";
      };
    };

    # TODO: set your radio hardware (the profile only sets the on-air parameters), e.g.
    # radio.type = "sx1262";
    # radio.sx1262 = { cs_pin = 21; reset_pin = 18; busy_pin = 20; irq_pin = 16; };

    # Virtual companion: connect a MeshCore client to <bindAddress>:<port>.
    companions."ORD-EXAMPLE-COMP" = {
      identityKeyFile = "/run/secrets/openhop-companion-key";
      bindAddress = "0.0.0.0";   # reachable on your LAN; the default is 127.0.0.1
      port = 5000;
      openFirewall = true;
    };

    # Test room server.
    roomServers."TestBBS" = {
      nodeName = "ORD-EXAMPLE-TEST";
      identityKeyFile = "/run/secrets/openhop-room-key";
      latitude = 41.8781;
      longitude = -87.6298;
      floodAdvertIntervalHours = 6;
      directAdvertIntervalHours = 2;
      adminPasswordFile = "/run/secrets/openhop-room-admin";
      guestPasswordFile = "/run/secrets/openhop-room-guest";
    };
  };
}
