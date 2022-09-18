# See configuration.nix(5) for more information.
# NOTE: be sure to disable virtualization capabilities within a VPS
# via "virtualisation.hypervGuest.enable" in the hardware configuration
# vim: fdm=marker

{ config, pkgs, lib, ... }:

let
  secrets = import ./secrets.nix;
in
  assert secrets.hostname != "";
  assert secrets.ethInterface != "";

{
  imports = [
    ./hardware-configuration.nix
  ];

  # boot {{{

  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/vda";
  };
  boot.loader.timeout = 2;

  boot.cleanTmpDir = true;
  boot.tmpOnTmpfs = true;
  boot.tmpOnTmpfsSize = "5%";

  # }}}

  # networking {{{

  networking.useDHCP = false; # False recommended for security reasons.
  networking.interfaces.${secrets.ethInterface}.useDHCP = true;
  networking.hostName = secrets.hostname;

  # }}}

  # localization {{{

  services.timesyncd.enable = true;
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # }}}

  # user space {{{

  users.mutableUsers = false;
  users.users.nixos = {
    isNormalUser = true;
    initialPassword = "test1234!";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ./keys.pub);
  };

  environment.systemPackages = with pkgs; [
    vim git
  ];

  # }}}

  # security and access {{{

  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      { groups = [ "wheel" ]; noPass = true; keepEnv = true; }
    ];
  };
  security.lockKernelModules = true; # disable loading kernel modules after boot

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
  };

  # }}}

  # optimization {{{

  # reduce systemd journaling
  services.journald.extraConfig =
  ''
    SystemMaxUse=250M
    MaxRetentionSec=7day
  '';

  # }}}

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}

