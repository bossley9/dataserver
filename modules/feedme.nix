{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.feedme;

  feedme = with pkgs; buildGoModule rec {
    pname = "feedme";
    version = "0.3.1";

    src = fetchFromSourcehut {
      owner = "~bossley9";
      repo = "${pname}";
      rev = "v${version}";
      sha256 = "19x8rc4pkbfxj10algaa87grqr9gqc3dv1kchh18v9cp5znja6n4";
    };

    vendorSha256 = "sha256-Gc1vlnYLy5Xrd9QQZERa7pjG7PhhEKWd+EWTbD43Qis=";

    meta = with lib; {
      description = "An Atom feed generator";
      homepage = "https://git.sr.ht/~bossley9/feedme";
      maintainers = with maintainers; [ bossley9 ];
      license = licenses.bsd2;
    };

    installPhase = ''
      mkdir -p $out/bin
      exe="$GOPATH/bin/cmd"
      [ -f "$exe" ] && cp $exe $out/bin/feedme
    '';
  };
in
{
  imports = [];

  options.services.feedme = {
    enable = mkEnableOption "the feedme service";
    domainName = mkOption {
      type = types.str;
      default = "localhost";
      example = "example.com";
      description = "The server domain name.";
    };
    port = mkOption {
      type = types.port;
      default = 9000;
      example = 8080;
      description = "The server port.";
    };
    certFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/etc/ssl/example.com.fullchain.pem";
      description = "The path to a TLS cert file.";
    };
    keyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/etc/ssl/example.com.key";
      description = "The path to a TLS key file.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.feedme = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${feedme}/bin/feedme \
          -d=${cfg.domainName} \
          -p=${builtins.toString cfg.port} \
          ${if cfg.certFile != null then "-c=${cfg.certFile}" else ""} \
          ${if cfg.keyFile != null then "-k=${cfg.keyFile}" else ""}
      '';
    };
  };
}
