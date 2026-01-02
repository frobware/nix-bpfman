# Cross-compiling bpfman on NixOS

This document captures the steps required to cross-compile bpfman for
different architectures (aarch64, ppc64le, s390x) on a NixOS system.

## Prerequisites

- Docker (for cross containers)
- rustup (can be installed via Nix/home-manager)
- The `cross` tool installed from git

## Two Independent Problems

Cross-compiling bpfman on NixOS requires solving two separate issues.
Both fixes are necessary - solving only one will still result in build failures.

### Problem 1: Old container images

The `cross` tool runs builds inside Docker containers that contain the cross-compilation toolchain. The version published to crates.io
(0.2.5) uses containers based on Ubuntu 16.04 (Xenial), which predates the `libbpf-dev` package - it was first available in Ubuntu 20.04.

bpfman's `Cross.toml` includes `apt-get install libbpf-dev` in its pre-build steps, which fails on the old images:

```
E: Unable to locate package libbpf-dev
```

**Solution:** Install cross from git. The main branch uses newer
container images based on Ubuntu 22.04 that include `libbpf-dev`.

```bash
cargo install cross --git https://github.com/cross-rs/cross --force
```

### Problem 2: Nix store paths confuse cross

Cross parses the rustc binary path to determine the active toolchain.
On NixOS, rustc typically lives at a path like:

```
/nix/store/a75nmxjfwc2vrw9rjzkwgazdzhn3yc6d-rust-toolchain/bin/rustc
```

Cross attempts to parse this as a toolchain name and fails:

```
error: invalid value '6rn84nnl2qkf0ssvb3zfz6833z62cx3y-rustc-1.89.0'
```

Or with newer cross versions:

```
error: unsupported os in target, abi: "1.89.0", system: "rustc"
```

Cross expects toolchains with conventional names like
`stable-x86_64-unknown-linux-gnu`, which is what rustup provides in
`~/.rustup/toolchains/`.

**Solution:** Ensure rustup-managed toolchain binaries appear in PATH
before the Nix-provided rustc.

```bash
# Ensure rustup's stable toolchain is installed
rustup toolchain install stable

# Verify it exists
ls ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/
```

Note: rustup itself can be installed via Nix/home-manager - that's
fine. The toolchains it manages in `~/.rustup/toolchains/` have the
conventional names cross expects.

## The Cross Build Command

The `cross-build-bpfman` script handles the PATH setup:

```bash
./cross-build-bpfman                                 # ARM64 release (default)
./cross-build-bpfman x86_64-unknown-linux-gnu        # x86_64 release
./cross-build-bpfman aarch64-unknown-linux-gnu       # ARM64 release
./cross-build-bpfman powerpc64le-unknown-linux-gnu   # POWER release
./cross-build-bpfman s390x-unknown-linux-gnu         # IBM Z release
./cross-build-bpfman aarch64-unknown-linux-gnu ""    # ARM64 debug
```

## Verifying the Build

```bash
# Check the binary architecture
file target/aarch64-unknown-linux-gnu/release/bpfman

# Expected output:
# ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV),
# dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, ...
```

## Cross.toml Configuration

The bpfman repository includes a `Cross.toml` that configures the
cross container with necessary dependencies:

```toml
[build]
default-target = "x86_64-unknown-linux-gnu"

pre-build = [
    "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable",
    ". $HOME/.cargo/env",
    "cargo install --force --locked bindgen-cli && mv $HOME/.cargo/bin/bindgen /usr/bin",
    "rm -rf $HOME/.cargo",
    "dpkg --add-architecture $CROSS_DEB_ARCH",
    "apt-get update && apt-get --assume-yes install clang libbpf-dev linux-libc-dev pkg-config libssl-dev:$CROSS_DEB_ARCH",
    "ln -sf /usr/include/$(uname -m)-linux-gnu/asm /usr/include/asm",
]
```

## Troubleshooting

### "no container engine found"

Ensure Docker is running and accessible:

```bash
docker info
```

### Other errors

See "Two Independent Problems" above for detailed explanations of:

- `invalid value '...-rustc-1.89.0'` - Problem 2 (PATH ordering)
- `unsupported os in target` - Problem 2 (PATH ordering)
- `Unable to locate package libbpf-dev` - Problem 1 (old images)

## Build Artefacts

After a successful build, binaries are in:

```
target/<target-triple>/release/
├── bpfman
├── bpfman-ns
├── bpfman-rpc
├── bpf-log-exporter
└── bpf-metrics-exporter
```
