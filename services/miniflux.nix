{ config, pkgs, ... }:

{
  imports = [
    ../modules/feedme.nix
  ];

  services.miniflux = {
    enable = true;
    adminCredentialsFile = builtins.toFile "miniflux-initial-credentials" ''
      ADMIN_USERNAME="admin"
      ADMIN_PASSWORD="test1234!"
    '';
    config = {
      WORKER_POOL_SIZE = "5"; # number of background workers
      POLLING_FREQUENCY = "60"; # feed refresh interval in minutes
      BATCH_SIZE = "100"; # number of feeds sent to queue each interval
      CLEANUP_ARCHIVE_READ_DAYS = "60"; # read items are removed after x days
      LISTEN_ADDR = "0.0.0.0:8001"; # address to listen on, 0.0.0.0 works better than localhost
    };
  };

  services.feedme = {
    enable = true;
    domainName = "0.0.0.0";
    port = 8002;
  };
}
