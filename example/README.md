# Example NixOS Configuration with bpfman

This repository provides an example NixOS configuration for the
"teapot" host, integrating `bpfman`. The [flake.nix](flake.nix) allows
you to build and run a VM with `bpfman` installed and running as a
system service.

## Usage

### Prerequisites

Ensure you have Nix installed on your system. For instructions, refer
to the [Nix installation guide](https://nixos.org/download.html).

### Running the Virtual Machine

To build and run the VM with `bpfman` integrated, use the following
command:

```sh
nix run
```

This command will:

1. Build the NixOS configuration for the `teapot` host.
2. Start a VM with `bpfman` running as a system service.
3. Automatically login you in as the `root` user.

### Flake Structure

- **inputs**: Specifies the dependencies of the flake.
  - `bpfman`: Local path to the `bpfman` flake.
  - `nixpkgs`: The Nixpkgs repository.

- **outputs**: Defines the outputs of the flake.
  - `supportedSystems`: List of supported system architectures.
  - `forAllSystems`: Helper function to generate attributes for all supported systems.
  - `bpfmanPkgs`: Imports `bpfman` packages for the specified system.
  - `mkSystem`: Creates the NixOS configuration for the specified system.
  - `runTeapotVM`: Creates a script to run the `teapot` VM.

### Configuration Details

The `mkSystem` function configures the NixOS system with the following modules
and settings:

- Imports the `bpfman` NixOS module.
- Adds `bpfman` to the system packages.
- Enables `bpfman` as a service.
- Sets the hostname to "teapot".
- Specifies the NixOS state version.
- Includes additional configuration from `vm-minimal.nix`.

### Running the VM

The `runTeapotVM` function creates a script to run the `teapot` VM
with QEMU. The VM will be started with `bpfman` running as a service,
and you can interact with it via the console.

# License

This project is licensed under the MIT License. See the
[LICENSE](LICENSE) file for details.
