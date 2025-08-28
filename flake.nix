{
  description = "A Nix flake & module packaging bpfman, an eBPF Manager for Linux and Kubernetes.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, systems, ... }: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);

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
    apps = forEachSystem (system: let
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

    checks = forEachSystem (system: {
      build = self.packages.${system}.default;
    });

    devShells = forEachSystem (system: let
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

        packages = [
          pkgs.clang
          pkgs.elfutils
          pkgs.go_1_24
          pkgs.libbpf
          pkgs.llvmPackages_latest.lldb  # Provides lldb-vscode
          pkgs.mold-wrapped
          pkgs.protobuf_32
          pkgs.protoc-gen-go
          pkgs.protoc-gen-go-grpc
          rust-toolchain
        ] ++ pkgs.lib.optionals (system == "x86_64-linux") [ pkgs.pkgsi686Linux.glibc ];
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

    packages = forEachSystem (system: let
      pkgs = nixpkgsWithOverlays system;
    in {
      bpfman = pkgs.bpfman;
      default = pkgs.bpfman;
    });
  };
}
