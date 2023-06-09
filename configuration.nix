{ config, pkgs, lib, ... }:

let
  email = "bossley.samuel@gmail.com";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    allowed-users = [ "@wheel" ];
  };

  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/vda";
    };
    timeout = 2;
  };

  networking = {
    hostName = "dataserver";
    useDHCP = false; # False recommended for security
    interfaces.ens3.useDHCP = true;
  };

  services.timesyncd.enable = true;
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  users.mutableUsers = false;
  users.users.nixos = {
    isNormalUser = true;
    initialPassword = "test1234!";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ./keys.pub);
  };
  environment.defaultPackages = lib.mkForce [ ]; # Remove default packages for security
  environment.systemPackages = with pkgs; [
    neovim
    git
  ];
  environment.shellInit = ''
    umask 0077
  '';
  programs.bash.shellInit = ''
    set -o vi
    alias vim="nvim"
    alias nrs="doas nixos-rebuild switch --flake .#"
  '';

  security = {
    sudo.enable = false;
    doas = {
      enable = true;
      extraRules = [
        { groups = [ "wheel" ]; noPass = true; keepEnv = true; }
      ];
    };
    lockKernelModules = true; # Disable loading kernel modules after boot
  };

  services.openssh = {
    enable = true;
    allowSFTP = false;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
    extraConfig = ''
      AuthenticationMethods publickey
    '';
  };
  services.sshguard.enable = true;

  # Automatically garbage collect nix
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  # Reduce systemd journaling
  services.journald.extraConfig = ''
    SystemMaxUse=250M
    MaxRetentionSec=7day
  '';
  services.cron = {
    enable = true;
    systemCronJobs = [
      # Reboot on Sundays at 3 AM
      "0 3 * * 0 root reboot"
    ];
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # OpenSSH (automatically allowed but explicitly adding for sanity)
      80 # HTTP
      443 # HTTPS
      25 # SMTP
    ];
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = email;
  };
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "news.bossley.us" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:8001";
      };
      "feedme.bossley.us" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:8002";
      };
      "git.bossley.us" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:8003";
      };
      "drive.bossley.us" = {
        forceSSL = true;
        enableACME = true;
      };
    };
  };

  system.stateVersion = "22.11"; # required
}
