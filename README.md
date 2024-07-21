# A Nix Flake that packages bpfman

This Nix [flake](https://nixos.wiki/wiki/Flakes) packages
[bpfman](https://bpfman.io) for [NixOS](https://nixos.org).

With this flake, you can:

- Install bpfman: Easily install the bpfman package on NixOS.

- Run bpfman as a Service: Use the provided [Nix
  module](https://nixos.wiki/wiki/NixOS_modules) to customise the
  installation and configuration of bpfman and run it as a systemd
  service.

## Nix Module Details

The Nix module provides several configuration options for integrating
bpfman into your NixOS system. The options available are:

- **services.bpfman.package**: Specifies the bpfman package to use. Defaults to `pkgs.bpfman`.
- **services.bpfman.service.enable**: Enables the bpfman-rpc service.
- **services.bpfman.service.environmentVariables**: Sets environment variables for the bpfman-rpc service. Defaults to `["RUST_LOG=Info"]`.
- **services.bpfman.socket.enable**: Enables the bpfman socket.
- **services.bpfman.socket.mode**: Sets the socket file mode. Defaults to `"0660"`.
- **services.bpfman.socket.path**: Specifies the path to the bpfman socket. Defaults to `"/run/bpfman-sock/bpfman.sock"`.

When `services.bpfman.service.enable` is set to `true`, the
`bpfman-rpc` service will be configured to start with the specified
environment variables, and it will restart automatically if it stops.
Additionally, enabling the socket with `services.bpfman.socket.enable`
will configure the socket with the provided path and mode.

# Example NixOS Usage

This example demonstrates how to import the bpfman flake into a NixOS
configuration. The example assumes that your NixOS configuration is
based on flakes.

```nix
{
  description = "NixOS configuration for the 'teapot' host with bpfman";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bpfman.url = "github:frobware/nix-bpfman";
  };

  outputs = { self, bpfman, nixpkgs, ... }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      overlays = [ bpfman.overlays.default ];
    };
  in {
    nixosConfigurations.teapot = nixpkgs.lib.nixosSystem {
      inherit system pkgs;

      modules = [
        bpfman.nixosModules.bpfman

        ({ pkgs, ... }: {
          services.bpfman.service.enable = true;
          services.bpfman.socket.enable = true;

          environment.systemPackages = [
            pkgs.bpfman
          ];
        })
      ];
    };
  };
}
```

# Flake Outputs

This flake provides several outputs to facilitate the use of bpfman
across different architectures and configurations. Below is an
overview of the available outputs:

```sh
% nix flake show --all-systems
git+file:///home/aim/src/github.com/frobware/nix-bpfman
├───apps
│   ├───aarch64-linux
│   │   ├───bpfman: app
│   │   └───default: app
│   └───x86_64-linux
│       ├───bpfman: app
│       └───default: app
├───checks
│   ├───aarch64-linux
│   │   └───build: derivation 'bpfman-0.5.0'
│   └───x86_64-linux
│       └───build: derivation 'bpfman-0.5.0'
├───devShells
│   ├───aarch64-linux
│   │   └───default: development environment 'nix-shell'
│   └───x86_64-linux
│       └───default: development environment 'nix-shell'
├───nixosModules
│   ├───bpfman: NixOS module
│   └───default: NixOS module
├───overlays
│   ├───bpfman: Nixpkgs overlay
│   └───default: Nixpkgs overlay
└───packages
    ├───aarch64-linux
    │   ├───bpfman: package 'bpfman-0.5.0'
    │   └───default: package 'bpfman-0.5.0'
    └───x86_64-linux
        ├───bpfman: package 'bpfman-0.5.0'
        └───default: package 'bpfman-0.5.0'
```

# A Runnable NixOS Configuration with bpfman

This repository provides an [example](example/README.md) NixOS
configuration for the "teapot" host, integrating bpfman. The [example
flake.nix](example/flake.nix) allows you to easily build and run a VM
with bpfman installed and running as a system service.

```sh
$ cd example
$ nix run
<<< Welcome to NixOS 24.11.20240720.d43f063 (x86_64) - ttyS0 >>>

Run 'nixos-help' for the NixOS manual.

teapot login: root (automatic login)

[root@teapot:~]# systemctl status bpfman.service
● bpfman.service - Run bpfman-rpc as a service
     Loaded: loaded (/etc/systemd/system/bpfman.service; enabled; preset: enabled)
     Active: active (running) since Sun 2024-07-21 19:51:57 UTC; 12s ago
TriggeredBy: ● bpfman.socket
   Main PID: 870 (bpfman-rpc)
         IP: 0B in, 0B out
         IO: 0B read, 0B written
      Tasks: 2 (limit: 2346)
     Memory: 2.3M (peak: 2.6M)
        CPU: 5ms
     CGroup: /system.slice/bpfman.service
             └─870 /nix/store/1nj8hzhab455yb8q0rrpzr116mggz8iy-bpfman-0.5.0/bin/bpfman-rpc

Jul 21 19:51:57 teapot systemd[1]: bpfman.service: Scheduled restart job, restart counter is at 10.
Jul 21 19:51:57 teapot systemd[1]: Started Run bpfman-rpc as a service.
Jul 21 19:51:57 teapot bpfman-rpc[870]: Using a Unix socket from systemd
Jul 21 19:51:57 teapot bpfman-rpc[870]: Using inactivity timer of 15 seconds
Jul 21 19:51:57 teapot bpfman-rpc[870]: Listening on /run/bpfman-sock/bpfman.sock

[root@teapot:~]# systemctl status bpfman.socket
● bpfman.socket - bpfman API Socket
     Loaded: loaded (/etc/systemd/system/bpfman.socket; enabled; preset: enabled)
     Active: active (running) since Sun 2024-07-21 19:49:24 UTC; 3min 13s ago
   Triggers: ● bpfman.service
     Listen: /run/bpfman-sock/bpfman.sock (Stream)
     CGroup: /system.slice/bpfman.socket

Jul 21 19:49:24 teapot systemd[1]: Listening on bpfman API Socket.

[root@teapot:~]# bpfman list
 Program ID  Name  Type  Load Time
```

# Nix Substituters / pre-built bpfman Package

To use the pre-built bpfman package from
[frobware.cachix.org](https://frobware.cachix.org), you can configure
your NixOS system to use this cache. This allows you to quickly
install the bpfman package without having to build it locally.

## Automatic Installation Using `cachix`

If you have the `cachix` package installed, you can run the following
command to update your ~/.config/nix/nix.conf to include
`frobware.cachix.org`:

```sh
cachix use frobware
```

## Manual Configuration

Add the following configuration to your nix.conf file:

```
{
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://frobware.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "frobware.cachix.org-1:bXV5FjZTALVuEDBq8TXPPa+xWvmCeihDTltC9leK6FI="
  ];
}
```

You can also add this configuration directly in your NixOS
configuration file:

```
{
  nix = {
    settings.substituters = [
      "https://cache.nixos.org"
      "https://frobware.cachix.org"
    ];

    settings.trusted-public-keys = [
      "frobware.cachix.org-1:bXV5FjZTALVuEDBq8TXPPa+xWvmCeihDTltC9leK6FI="
    ];
  };
}
```

By adding these lines, your NixOS system will use
[frobware.cachix.org](https://frobware.cachix.org) to fetch pre-built
binaries, reducing build times.

# License

This project is licensed under the MIT License. See the
[LICENSE](LICENSE) file for details.
