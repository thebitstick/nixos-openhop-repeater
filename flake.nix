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
    in
    {
      overlays.default = final: _prev: {
        openhop-repeater = final.callPackage ./package.nix { };
      };

      nixosModules.default = module;

      packages = forAll (pkgs: rec {
        openhop-repeater = pkgs.callPackage ./package.nix { };
        default = openhop-repeater;
        options-doc =
          let
            eval = nixpkgs.lib.nixosSystem {
              inherit (pkgs.stdenv.hostPlatform) system;
              modules = [ module ];
            };
          in
          (pkgs.nixosOptionsDoc {
            options = eval.options.services.openhop-repeater;
            transformOptions =
              opt:
              opt
              // {
                declarations = [ ];
              };
          }).optionsCommonMark;
      });

      checks = forAll (
        pkgs:
        import ./tests {
          inherit pkgs module;
          inherit (nixpkgs.lib) nixosSystem;
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
