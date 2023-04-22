{ config, pkgs, ... }:

{
  services.gitea = {
    enable = true;
    appName = "Gitea";
    database.type = "postgres";
    settings = {
      repository = {
        DEFAULT_PRIVATE = "private";
      };
      service.DISABLE_REGISTRATION = true;
      server = {
        HTTP_PORT = 8003;
        ROOT_URL = "https://git.bossley.us";
      };
      session = {
        COOKIE_SECURE = true;
      };
    };
  };
}
