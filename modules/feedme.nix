{ config, pkgs, lib, ... }:

let
  cfg = config.services.feedme;

  feedme = with pkgs; buildGoModule rec {
    pname = "feedme";
    version = "0.4.0";

    src = fetchFromGitHub {
      owner = "bossley9";
      repo = "${pname}";
      rev = "v${version}";
      sha256 = "03mspgxnyim1p7yz5q1pwpnybrzm16xgf3jxqzvnzq2hmcam0f5b";
    };

    vendorHash = "sha256-OmGzqndx1cMhovode9w9XJ7BOJmjz+9ntYMRL5MEVm0=";

    meta = with lib; {
      description = "An Atom feed generator";
      homepage = "https://github.com/bossley9/feedme";
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
  imports = [ ];

  options.services.feedme = {
    enable = lib.mkEnableOption "the feedme service";
    domainName = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      example = "example.com";
      description = "The server domain name.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      example = 8080;
      description = "The server port.";
    };
    certFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/ssl/example.com.fullchain.pem";
      description = "The path to a TLS cert file.";
    };
    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/ssl/example.com.key";
      description = "The path to a TLS key file.";
    };
  };

  config = lib.mkIf cfg.enable {
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
