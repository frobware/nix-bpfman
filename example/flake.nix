{
  description = "NixOS config for host 'teapot' with bpfman and a runnable VM.";

  inputs = {
    bpfman.url = "..";
    nixpkgs.follows = "bpfman/nixpkgs";
    systems.follows = "bpfman/systems";
  };

  outputs = { self, bpfman, nixpkgs, systems, ... }: let
    linuxSystems = builtins.filter (s: nixpkgs.lib.hasSuffix "-linux" s) (import systems);
    forEachSystem = nixpkgs.lib.genAttrs linuxSystems;

    pkgsFor = system: import nixpkgs {
      inherit system;
      overlays = [ bpfman.overlays.default ];
    };

    mkTeapotSystem = system: nixpkgs.lib.nixosSystem {
      inherit system;
      pkgs = pkgsFor system;
      modules = [
        bpfman.nixosModules.bpfman

        ({ ... }: {
          networking.hostName = "teapot";
          system.stateVersion = "25.05";
        })

        ({ pkgs, ... }: {
          environment.systemPackages = [ pkgs.bpfman ];
          services.bpfman.service.enable = true;
          services.bpfman.socket.enable = true;
        })

        (import ./vm-minimal.nix)
      ];
    };
  in
  {
    nixosConfigurations = builtins.listToAttrs (map (system: {
      name = "teapot-${system}";
      value = mkTeapotSystem system;
    }) linuxSystems);

    packages = forEachSystem (system: {
      default =
        self.nixosConfigurations."teapot-${system}".config.system.build.vm;
    });

    checks = forEachSystem (system: {
      build = self.packages.${system}.default;
    });

    # App to run the VM with a sane serial console and memory size.
    apps = forEachSystem (system: let
      pkgs = pkgsFor system;
      vm = self.nixosConfigurations."teapot-${system}".config.system.build.vm;
      runner = pkgs.writeShellScriptBin "run-teapot-vm" ''
        #!${pkgs.runtimeShell}
        set -euo pipefail
        # Keep logs on the serial console to make debugging easy.
        QEMU_KERNEL_PARAMS=console=ttyS0 ${vm}/bin/run-teapot-vm -nographic -m 2G
      '';
    in {
      default = {
        type = "app";
        program = "${runner}/bin/run-teapot-vm";
      };
    });
  };
}
