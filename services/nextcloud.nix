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
    };
    https = true;
    maxUploadSize = "2G";
    enableImagemagick = false; # see https://github.com/nextcloud/server/issues/13099
  };
}
