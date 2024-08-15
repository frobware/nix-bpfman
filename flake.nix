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
      rust-toolchain = pkgs.symlinkJoin {
        name = "rust-toolchain";
        paths = [
          pkgs.cargo
          pkgs.clippy
          pkgs.rust-analyzer
          pkgs.rustPlatform.rustcSrc
          pkgs.rustc
          pkgs.rustfmt
        ];
      };
    in {
      default = pkgs.mkShell {
        hardeningDisable = [
          "stackprotector"
          # zerocallusedregs: https://github.com/NixOS/nixpkgs/pull/325587
          "zerocallusedregs"
        ];
        inputsFrom = [ self.packages.${system}.default ];

        # These packages are needed to develop and build parts of the
        # bpfman tree, notably, the examples directory (make build,
        # generate, et al), libbpf/src.
        packages = [
          pkgs.clang
          pkgs.elfutils
          pkgs.go_1_22
          pkgs.libbpf
          pkgs.pkgsi686Linux.glibc
          pkgs.protobuf3_23
          pkgs.protoc-gen-go
          pkgs.protoc-gen-go-grpc

          rust-toolchain
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
