# See configuration.nix(5) for more information.
# NOTE: be sure to disable virtualization capabilities within a VPS
# via "virtualisation.hypervGuest.enable" in the hardware configuration
# vim: fdm=marker

{ config, pkgs, lib, ... }:

let
  secrets = import ./secrets.nix;
  isFirstRun = if secrets ? isFirstRun then secrets.isFirstRun else false;
  userHome = /home/nixos;
  gitHome = /home/git;
  vaultHome = /home/vault;
  minifluxPort = 8001;
  feedmePort = 8002;
  bitwardenPort = 8003;

in
  assert secrets.hostname != "";
  assert secrets.ethInterface != "";
  assert secrets.email != "";
  assert secrets.minifluxDomain != "";
  assert secrets.feedmeDomain != "";
  assert secrets.bitwardenDomain != "";

{
  imports = [
    ./hardware-configuration.nix
    ./modules/feedme.nix
  ];

  # boot {{{
  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/vda";
  };
  boot.loader.timeout = 2;
  # }}}

  # networking {{{
  networking.useDHCP = false; # False recommended for security
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
    home = (builtins.toString userHome);
    openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ./keys.pub);
  };

  environment.defaultPackages = lib.mkForce []; # Remove default packages for security
  environment.systemPackages = with pkgs; [
    vim git
  ];

  environment.shellInit = ''
    umask 0077
  '';
  # }}}

  # security and access {{{
  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      { groups = [ "wheel" ]; noPass = true; keepEnv = true; }
    ];
  };
  nix.allowedUsers = [ "@wheel" ];
  security.lockKernelModules = true; # Disable loading kernel modules after boot

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
    allowSFTP = false;
    forwardX11 = false;
    extraConfig = ''
      AuthenticationMethods publickey
    '';
  };
  services.sshguard.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # OpenSSH (automatically allowed but explicitly adding for sanity)
      80 443 # HTTP and HTTPS
    ];
    # allowedUDPPorts = [ ... ];
  };
  # }}}

  # optimization {{{
  # Automatically garbage collect nix
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  # Reduce systemd journaling
  services.journald.extraConfig =
  ''
    SystemMaxUse=250M
    MaxRetentionSec=7day
  '';
  # }}}

  # miniflux {{{
  services.miniflux = {
    enable = true;
    adminCredentialsFile = builtins.toFile "miniflux-admin-credentials" ''
      ADMIN_USERNAME=${secrets.minifluxInitialAdminUsername}
      ADMIN_PASSWORD=${secrets.minifluxInitialAdminPassword}
    '';
    config = {
      WORKER_POOL_SIZE = "5"; # number of background workers
      POLLING_FREQUENCY = "60"; # feed refresh interval in minutes
      BATCH_SIZE = "100"; # number of feeds sent to queue each interval
      LISTEN_ADDR = "0.0.0.0:${builtins.toString minifluxPort}"; # address to listen on, 0.0.0.0 works better than localhost
      CLEANUP_ARCHIVE_READ_DAYS = "60"; # read items are removed after x days
    };
  };
  # }}}

  # feedme {{{
  services.feedme = {
    enable = true;
    domainName = "0.0.0.0";
    port = feedmePort;
  };
  # }}}

  # git server {{{
  programs.git = {
    enable = true;
    config.init.defaultBranch = "main";
  };
  users.users.git = {
    isNormalUser = true;
    description = "git user";
    createHome = true;
    home = (builtins.toString gitHome);
    openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ./keys.pub);
  };
  # }}}

  # bitwarden (vaultwarden) {{{
  users.users.vaultwarden = {
    isSystemUser = true;
    description = "Bitwarden vault user";
    createHome = true;
    home = (builtins.toString vaultHome);
  };
  services.vaultwarden = {
    enable = true;
    backupDir = (builtins.toString vaultHome) + "/vault-backup";
    config = {
      DOMAIN = "https://" + secrets.bitwardenDomain;
      SIGNUPS_ALLOWED = isFirstRun;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = bitwardenPort;
    };
  };
  # }}}

  # nginx (webserver and reverse proxies) {{{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = secrets.email;
  services.nginx = {
    enable = true;
    virtualHosts = {
      "${secrets.minifluxDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:${builtins.toString minifluxPort}";
      };
      "${secrets.feedmeDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:${builtins.toString feedmePort}";
      };
      "${secrets.bitwardenDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:${builtins.toString bitwardenPort}";
      };
    };
  };
  # }}}

  # required {{{
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
  # }}}
}

