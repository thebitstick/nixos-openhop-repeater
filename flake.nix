{
  description = "NixOS module and package for openHop Repeater (MeshCore repeater daemon)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      module = ./module.nix;
      darwinSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Pure Python, so it also runs on macOS.
      convertKey =
        pkgs:
        pkgs.writers.writePython3Bin "openhop-convert-key" {
          flakeIgnore = [
            "E"
            "W"
          ];
        } (builtins.readFile ./scripts/convert-firmware-key.py);
    in
    {
      overlays.default = final: _prev: {
        openhop-repeater = final.callPackage ./package.nix { };
      };

      nixosModules.default = module;

      packages =
        (forAll (pkgs: rec {
          openhop-repeater = pkgs.callPackage ./package.nix { };
          default = openhop-repeater;
          convert-key = convertKey pkgs;
          options-doc =
            let
              eval = nixpkgs.lib.nixosSystem {
                inherit (pkgs.stdenv.hostPlatform) system;
                modules = [ module ];
              };
              commonmark =
                (pkgs.nixosOptionsDoc {
                  options = eval.options.services.openhop-repeater;
                  transformOptions = opt: opt // { declarations = [ ]; };
                }).optionsCommonMark;
            in
            pkgs.runCommand "openhop-repeater-options.md" { } ''
              {
                cat ${pkgs.writeText "options-header.md" ''
                  # Module options

                  Every `services.openhop-repeater.*` option, with its type, default and description.
                  This file is generated from the module by `scripts/update-generated.sh`. Do not edit it by
                  hand: the `docs-in-sync` check fails if it is out of date.

                ''}
                cat ${commonmark}
              } > $out
            '';
        }))
        // nixpkgs.lib.genAttrs darwinSystems (system: {
          convert-key = convertKey nixpkgs.legacyPackages.${system};
        });

      apps = nixpkgs.lib.genAttrs (systems ++ darwinSystems) (system: {
        convert-key = {
          type = "app";
          program = "${self.packages.${system}.convert-key}/bin/openhop-convert-key";
        };
      });

      checks = forAll (
        pkgs:
        import ./tests {
          inherit pkgs module;
          inherit (nixpkgs.lib) nixosSystem;
          inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) options-doc convert-key;
          package = self.packages.${pkgs.stdenv.hostPlatform.system}.openhop-repeater;
        }
      );

      formatter = nixpkgs.lib.genAttrs (
        systems
        ++ [
          "aarch64-darwin"
          "x86_64-darwin"
        ]
      ) (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
