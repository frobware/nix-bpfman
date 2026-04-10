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

      # Cross-compilation toolchains for nsenter CGO testing.
      # Nix cross-compiled binaries embed absolute Nix store paths
      # in PT_INTERP, so QEMU user-mode can load them without -L.
      crossAarch64 = pkgs.pkgsCross.aarch64-multiplatform;
      crossPpc64le = pkgs.pkgsCross.powernv;
      crossS390x   = pkgs.pkgsCross.s390x;

      # Convenience script to run nsenter package tests across
      # architectures using cross-compilation and QEMU user-mode.
      #
      # Usage:
      #   nsenter-cross-test          # all architectures
      #   nsenter-cross-test arm64    # single architecture
      #
      # Subprocess re-exec tests (TestConstructorWithoutNamespace,
      # TestConstructorWithSelfNamespace) require binfmt_misc to be
      # registered for the target architecture so the kernel can
      # route cross-compiled binaries through QEMU automatically.
      # Without binfmt_misc those subtests are skipped.
      nsenter-cross-test = pkgs.writeShellScriptBin "nsenter-cross-test" ''
        set -euo pipefail

        arch="''${1:-all}"

        run_test() {
          local label="$1" goarch="$2" cc="$3" qemu_bin="$4"
          echo "=== nsenter: $label ($goarch) ==="
          local -a exec_args=()
          if [ -n "$qemu_bin" ]; then
            exec_args=(-exec "$qemu_bin")
          fi
          CGO_ENABLED=1 GOOS=linux GOARCH="$goarch" CC="$cc" \
            go test -v -count=1 "''${exec_args[@]}" ./ns/nsenter/
        }

        if [ "$arch" = "amd64" ] || [ "$arch" = "all" ]; then
          run_test "native" amd64 gcc ""
        fi
        if [ "$arch" = "arm64" ] || [ "$arch" = "all" ]; then
          run_test "arm64 (QEMU)" arm64 \
            aarch64-unknown-linux-gnu-gcc qemu-aarch64
        fi
        if [ "$arch" = "ppc64le" ] || [ "$arch" = "all" ]; then
          run_test "ppc64le (QEMU)" ppc64le \
            powerpc64le-unknown-linux-gnu-gcc qemu-ppc64le
        fi
        if [ "$arch" = "s390x" ] || [ "$arch" = "all" ]; then
          run_test "s390x (QEMU)" s390x \
            s390x-unknown-linux-gnu-gcc qemu-s390x
        fi
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
          pkgs.cosign  # image signing (parity with the CI image-build workflow)
          pkgs.elfutils
          pkgs.glibc.static
          pkgs.go_1_25
          pkgs.libbpf
          pkgs.llvmPackages_latest.lldb  # Provides lldb-vscode
          pkgs.mold
          pkgs.protobuf_32
          pkgs.protoc-gen-go
          pkgs.protoc-gen-go-grpc
          # QEMU and cloud-init dependencies
          pkgs.qemu_kvm
          pkgs.qemu-user  # user-mode emulators for cross-arch nsenter testing
          pkgs.cdrkit  # provides genisoimage
          pkgs.virtiofsd
          rust-toolchain
          bpfman-go-generate-examples # wrapper for `make -C examples generate`.
          bpfman-dev-qemu  # QEMU development VM
          nsenter-cross-test  # cross-arch nsenter CGO test runner
          crossAarch64.stdenv.cc
          crossPpc64le.stdenv.cc
          crossS390x.stdenv.cc
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
