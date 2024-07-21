{
  description = "An example NixOS configuration for the 'teapot' host with bpfman.";

  inputs = {
    bpfman.url = "github:frobware/nix-bpfman";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, bpfman, nixpkgs, ... }: let
    supportedSystems = ["aarch64-linux" "x86_64-linux"];

    forAllSystems = function: nixpkgs.lib.genAttrs supportedSystems (
      system: function system
    );

    bpfmanPkgs = system: import nixpkgs {
      inherit system;
      overlays = [ bpfman.overlays.default ];
      nixpkgs.config = {
        doCheck = false;
      };
    };

    mkSystem = system: let
      pkgs = bpfmanPkgs system;
    in nixpkgs.lib.nixosSystem {
      inherit system pkgs;
      modules = [
        bpfman.nixosModules.bpfman
        ({ pkgs, ... }: {
          environment.systemPackages = [ pkgs.bpfman ];
          services.bpfman.service.enable = true;
          services.bpfman.socket.enable = true;
        })
        ({ ... }: {
          networking.hostName = "teapot";
        })
        ({ ... }: {
          system.stateVersion = "24.05";
        })
        (import ./vm-minimal.nix)
      ];
    };

    runTeapotVM = system: let
      pkgs = bpfmanPkgs system;
    in pkgs.writeShellScriptBin "run-teapot-vm" ''
      #!${pkgs.runtimeShell} -e
      QEMU_KERNEL_PARAMS="console=ttyS0" ${self.nixosConfigurations."teapot-${system}".config.system.build.vm}/bin/run-teapot-vm -nographic -m 2G
    '';
  in {
    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${runTeapotVM system}/bin/run-teapot-vm";
      };
    });

    checks = forAllSystems (system: {
      build = self.packages.${system}.default;
    });

    nixosConfigurations = builtins.listToAttrs (map (system: {
      name = "teapot-${system}";
      value = mkSystem system;
    }) supportedSystems);

    packages = forAllSystems (system: {
      default = self.nixosConfigurations."teapot-${system}".config.system.build.vm;
    });
  };
}
