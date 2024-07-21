{ modulesPath, ... }:

{
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.pulseaudio.enable = false;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  networking.networkmanager.enable = false;
  networking.useDHCP = false;

  services.avahi.enable = false;
  services.cron.enable = false;
  services.openssh.enable = false;
  services.pipewire.enable = false;
  services.xserver.enable = false;

  services.getty.autologinUser = "root";
}
