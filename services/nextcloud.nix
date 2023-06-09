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
    caching.redis = true;
    configureRedis = true;
    phpOptions = {
      "opcache.enable" = "1";
      "opcache.enable_cli" = "1";
      "opcache.interned_strings_buffer" = "8";
      "opcache.max_accelerated_files" = "10000";
      "opcache.revalidate_freq" = "1";
      "opcache.save_comments" = "1";
      "opcache.memory_consumption" = "512";
      "opcache.jit" = "1255";
      "opcache.jit_buffer_size" = "128M";
    };
    https = true;
    maxUploadSize = "4G";
    enableImagemagick = false; # see https://github.com/nextcloud/server/issues/13099
    extraOptions = {
      mail_smtpmode = "sendmail";
      mail_smtpport = 25;
      mail_domain = "mail.bossley.us";
    };
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
  services.postfix = {
    enable = true;
    extraMasterConf = ''
      postlog unix-dgram n - n - 1 postlogd
    '';
    config = {
      maillog_file = "/var/log/postfix.log";
      maillog_file_permissions = "0644";
      inet_interfaces = "loopback-only";
      myhostname = "mail.bossley.us";
      mydomain = "mail.bossley.us";
      mydestination = "localhost.$mydomain, localhost, $myhostname";
    };
  };
}
