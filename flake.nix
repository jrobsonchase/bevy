{
  description = "Bevy";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    rustpkgs.url = "github:oxalica/rust-overlay";
    cargo2nix.url = "github:cargo2nix/cargo2nix";
    cargo2nix.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, rustpkgs, ... }@inputs:
    let
      systems = [
        "x86_64-linux"
        "i686-linux"
      ];
    in
    flake-utils.lib.eachSystem systems
      (system:
        let
          cargo2nix = import inputs.cargo2nix { inherit system; };

          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rustpkgs.overlay
              (import "${inputs.cargo2nix}/overlay")
            ];
          };

          mkOverride = pkgs': name: { buildInputs ? [ ], nativeBuildInputs ? [ ] }:
            pkgs'.rustBuilder.rustLib.makeOverride {
              name = name;
              overrideAttrs = drv: {
                propagatedNativeBuildInputs = drv.propagatedNativeBuildInputs or [ ] ++
                  nativeBuildInputs;
                propagatedBuildInputs = drv.buildInputs or [ ] ++
                  buildInputs;
              };
            };

          mkOverrides = f: pkgs':
            pkgs'.rustBuilder.overrides.all ++
            (nixpkgs.lib.mapAttrsToList (mkOverride pkgs') (f pkgs'));


          rustChannel = "1.55.0";

          rustPkgs = pkgs.rustBuilder.makePackageSet' {
            packageOverrides = mkOverrides (pkgs': {
              alsa-sys = {
                buildInputs = [
                  pkgs'.alsa-lib
                ];
                nativeBuildInputs = [
                  pkgs'.pkgconfig
                ];
              };
            });

            inherit rustChannel;
            packageFun = import ./Cargo.nix;
          };
        in
        rec {
          packages = {
            cargo2nix = cargo2nix.package;
          } // nixpkgs.lib.mapAttrs (name: value: value {}) rustPkgs.workspace;
          defaultPackage = packages.bevy_math;
          devShell = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              pkgconfig
            ];
            buildInputs = with pkgs; [
              rust-bin.stable.${rustChannel}.minimal
              alsa-lib
              udev
              packages.cargo2nix
            ];
          };
        });
}
