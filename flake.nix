{
  description = "A Nix flake & module packaging bpfman, an eBPF Manager for Linux and Kubernetes.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, systems, ... }: let
    linuxSystems = builtins.filter (s: nixpkgs.lib.hasSuffix "-linux" s) (import systems);
    forEachSystem = nixpkgs.lib.genAttrs linuxSystems;

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

      # Script to run make -C examples generate with unwrapped clang
      # for BPF compilation.
      bpfman-go-generate-examples = pkgs.writeShellScriptBin "bpfman-go-generate-examples" ''
        set -euo pipefail
        export PATH="${pkgs.llvmPackages.clang-unwrapped}/bin:$PATH"
        CLANG_VERSION=${pkgs.lib.versions.major pkgs.llvmPackages.clang-unwrapped.version}
        CLANG_INCLUDES="${pkgs.lib.getLib pkgs.llvmPackages.clang-unwrapped}/lib/clang/$CLANG_VERSION/include"
        export C_INCLUDE_PATH="${pkgs.linuxHeaders}/include:${pkgs.libbpf}/include:${pkgs.glibc.dev}/include:$CLANG_INCLUDES"
        echo "Using clang: $(which clang)"
        make -C examples generate
      '';

      # QEMU-based development VM script
      bpfman-dev-qemu = pkgs.writeShellScriptBin "bpfman-dev-qemu" ''
        exec ${./scripts/bpfman-dev-qemu.sh} "$@"
      '';
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
          pkgs.go_1_25
          pkgs.libbpf
          pkgs.llvmPackages_latest.lldb  # Provides lldb-vscode
          pkgs.mold
          pkgs.protobuf_32
          pkgs.protoc-gen-go
          pkgs.protoc-gen-go-grpc
          # QEMU and cloud-init dependencies
          pkgs.qemu_kvm
          pkgs.cdrkit  # provides genisoimage
          pkgs.virtiofsd
          rust-toolchain
          bpfman-go-generate-examples # wrapper for `make -C examples generate`.
          bpfman-dev-qemu  # QEMU development VM
          self.packages.${system}.bpfman-operator-component-override
          # CI linting tools (cross installed via: cargo install cross --git https://github.com/cross-rs/cross)
          pkgs.cargo-llvm-cov  # code coverage
          pkgs.taplo  # TOML linter (taplo fmt --check)
          pkgs.yamllint  # YAML linter
          pkgs.clang-tools  # clang-format for C code formatting
          pkgs.golangci-lint  # Go linter
          # Documentation tools
          pkgs.uv  # Python package manager for mkdocs
          pkgs.mkdocs  # documentation generator
        ];
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
      bpfman-operator-component-override = pkgs.writeShellApplication {
        name = "bpfman-operator-component-override";
        runtimeInputs = [ pkgs.kubectl pkgs.jq ];
        text = ''
          exec -a bpfman-operator-component-override ${./scripts/bpfman-operator-component-override} "$@"
        '';
      };
      default = pkgs.bpfman;
    });
  };
}
