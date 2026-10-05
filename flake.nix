{
  description = "NixOS module and package for openHop Repeater (MeshCore repeater daemon)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in
    {
      overlays.default = final: _prev: {
        openhop-repeater = final.callPackage ./package.nix { };
      };

      packages = forAll (pkgs: rec {
        openhop-repeater = pkgs.callPackage ./package.nix { };
        default = openhop-repeater;
      });

      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./module.nix ];
        services.openhop-repeater.package =
          lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.openhop-repeater;
      };
    };
}
