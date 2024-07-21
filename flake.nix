{
  description = "A Nix flake & module packaging bpfman, an eBPF Manager for Linux and Kubernetes.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: let
    forAllSystems = function: nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux"] (
      system: function system
    );

    nixpkgsWithOverlays = system: import nixpkgs {
      inherit system;
      overlays = [ self.overlays.default ];
    };

    bpfmanOverlay = final: prev: {
      bpfman = prev.callPackage ./package.nix {
        # Options are: debug or release.
        bpfmanBuildType = "release";
      };
    };
  in {
    apps = forAllSystems (system: let
      pkgs = nixpkgsWithOverlays system;
    in {
      bpfman = {
        type = "app";
        program = "${pkgs.bpfman}/bin/bpfman";
      };
      default = {
        type = "app";
        program = "${pkgs.bpfman}/bin/bpfman";
      };
    });

    checks = forAllSystems (system: {
      build = self.packages.${system}.default;
    });

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = [
          self.packages.${system}.default.buildInputs
          self.packages.${system}.default.nativeBuildInputs
        ];
        shellHook = ''
          echo "Development environment for bpfman on ${system}."
        '';
      };
    });

    nixosModules = {
      bpfman = import ./module.nix;
      default = import ./module.nix;
    };

    overlays = {
      bpfman = bpfmanOverlay;
      default = bpfmanOverlay;
    };

    packages = forAllSystems (system: let
      pkgs = nixpkgsWithOverlays system;
    in {
      bpfman = pkgs.bpfman;
      default = pkgs.bpfman;
    });
  };
}
