{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    fenix.url = "github:nix-community/fenix";
    crate2nix.url = "github:nix-community/crate2nix";
  };

  outputs = { self, utils, nixpkgs, crate2nix, ... }@inputs: utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          inputs.fenix.overlays.default
        ];
      };

      toolchain-stable = inputs.fenix.packages.${system}.stable.withComponents [
        "cargo"
        "clippy"
        "rustc"
        "rustfmt"
      ];

      toolchain-nightly = inputs.fenix.packages.${system}.stable.withComponents [
        "cargo"
        "clippy"
        "miri"
        "rustc"
        "rustfmt"
      ];

      toolchain = toolchain-stable;

      inherit (pkgs) lib;
      inherit (lib) cleanSource cleanSourceWith;

      cargoNix = crate2nix.tools.${system}.generatedCargoNix {
        name = "generated-cargo-nix";
        src = cleanSource (cleanSourceWith {
          src = ./.;
          # Skip the cargo config when generating
          filter = (name: type: !((baseNameOf (toString name)) == ".cargo"));
        });
      };

      cargoWorkspace = pkgs.callPackage cargoNix {
        buildRustCrateForPkgs = pkgs: with pkgs; buildRustCrate.override {
          rustc = toolchain;
          cargo = toolchain;
        };
      };
    in
    {
      inherit cargoWorkspace;
      devShells.default = pkgs.mkShell {
        inputsFrom = [
          # Note: currently fails due to some crate2nix "can't find package" error
          # cargoWorkspace.workspaceMembers.bevy.build
        ];
        nativeBuildInputs = with pkgs; [
          pkg-config
        ];
        buildInputs = with pkgs; [
          toolchain
          udev
          alsa-lib
          wayland
          rust-analyzer-nightly
          taplo
          stdenv
        ];
        RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
        RUST_BACKTRACE = "true";
      };
    });
}
