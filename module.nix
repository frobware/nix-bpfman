{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.bpfman;
in {
  options.services.bpfman = {
    package = mkOption {
      type = types.package;
      default = pkgs.bpfman;
      description = "The bpfman package to use.";
    };

    service = {
      enable = mkEnableOption "Enable bpfman-rpc service";
      environmentVariables = mkOption {
        type = types.listOf types.str;
        default = ["RUST_LOG=Info"];
        example = ["RUST_LOG=Debug"];
        description = "Environment variables for the bpfman-rpc service.";
      };
    };

    socket = {
      enable = mkEnableOption "Enable bpfman socket";
      mode = mkOption {
        type = types.str;
        default = "0660";
        description = "Socket file mode.";
      };
      path = mkOption {
        type = types.str;
        default = "/run/bpfman-sock/bpfman.sock";
        description = "Path to the bpfman socket.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.service.enable {
      systemd.services.bpfman = {
        description = "Run bpfman-rpc as a service";
        after = [ "network.target" ];
        requires = [ "bpfman.socket" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Environment = cfg.service.environmentVariables;
          ExecStart = "${cfg.package}/bin/bpfman-rpc";
          Restart = "always";
        };
      };
    })

    (mkIf cfg.socket.enable {
      systemd.sockets.bpfman = {
        description = "bpfman API Socket";
        wantedBy = [ "sockets.target" ];
        socketConfig = {
          ListenStream = cfg.socket.path;
          SocketMode = cfg.socket.mode;
        };
      };
    })
  ];
}
