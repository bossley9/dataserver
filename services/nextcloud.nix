{ config, pkgs, ... }:

{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud26;
    hostName = "drive.bossley.us";
    config = {
      adminuser = "admin";
      adminpassFile = "${pkgs.writeText "nextcloud-initial-credentials" "test1234!"}";
      defaultPhoneRegion = "US";
      dbhost = "/run/postgresql";
      dbname = "nextcloud";
      dbtype = "pgsql";
      dbuser = "nextcloud";
    };
    https = true;
    maxUploadSize = "2G";
    enableImagemagick = false; # see https://github.com/nextcloud/server/issues/13099
  };
  # ensure Postgres DB setup happens before Nextcloud
  systemd.services."nextcloud-setup" = {
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
  };
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      {
        name = "nextcloud";
        ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
      }
    ];
  };
}
