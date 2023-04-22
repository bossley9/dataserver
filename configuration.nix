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
  # initial values
  adminUsername = "admin";
  adminPassword = "test1234";

in
assert secrets.email != "";
assert secrets.minifluxDomain != "";
assert secrets.feedmeDomain != "";
assert secrets.bitwardenDomain != "";
assert secrets.nextcloudDomain != "";
assert secrets.webserverDomain != "";

{
  imports = [
    ./hardware-configuration.nix
    ./modules/feedme.nix
  ];

  boot.loader = {
    grub = {
      enable = true;
      version = 2;
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
    home = (builtins.toString userHome);
    openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ./keys.pub);
  };

  environment.defaultPackages = lib.mkForce [ ]; # Remove default packages for security
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  environment.shellInit = ''
    umask 0077
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
  nix.allowedUsers = [ "@wheel" ];

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
      80 # HTTP
      443 # HTTPS
    ];
  };

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

  # miniflux {{{
  services.miniflux = {
    enable = true;
    adminCredentialsFile = builtins.toFile "miniflux-admin-credentials" ''
      ADMIN_USERNAME="${adminUsername}"
      ADMIN_PASSWORD="${adminPassword}"
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
      YUBICO_CLIENT_ID = if secrets ? bitwardenYubicoClientId then secrets.bitwardenYubicoClientId else "";
      YUBICO_SECRET_KEY = if secrets ? bitwardenYubicoSecretKey then secrets.bitwardenYubicoSecretKey else "";
      DOMAIN = "https://" + secrets.bitwardenDomain;
      SIGNUPS_ALLOWED = isFirstRun;
      INVITATIONS_ALLOWED = false;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = bitwardenPort;
    };
  };
  # }}}

  # nextcloud {{{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud24;
    hostName = secrets.nextcloudDomain;
    config = {
      adminuser = adminUsername;
      adminpassFile = "${pkgs.writeText "adminpass" "${adminPassword}"}";
    };
    https = true;
    maxUploadSize = "1G";
    enableImagemagick = false; # see https://github.com/nextcloud/server/issues/13099
  };
  # }}}

  # nginx (webserver and reverse proxies) {{{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = secrets.email;
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "${secrets.webserverDomain}" = {
        forceSSL = true;
        enableACME = true;
        root = "/var/www/${secrets.webserverDomain}";
      };
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
      "${secrets.nextcloudDomain}" = {
        forceSSL = true;
        enableACME = true;
      };
    };
  };
  # }}}

  system.stateVersion = "22.11"; # required
}

