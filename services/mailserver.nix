# Send-only postfix mail server for password reset and notification emails, mostly.
# First, set up DNS records:
# TXT subdomain "v=spf1 ip4:xxx.xx.xxx.xx ip6:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx ~all"
# TXT _dmarc.subdomain "v=DMARC1; p=reject; pct=100"
# MX subdomain 0 subdomain.domain.com
# (inserted DNS record from /var/dkim/default.txt)
# TXT default._domainkey.subomain "v=DKIM1; k=rea; ..."
#
# To test mail delivery with sendmail:
# printf "Subject: First newsletter\nThis is our first official newsletter email." | sendmail your@email.com

{ config, lib, pkgs, ... }:

let
  mailDomain = "mail.bossley.us";

  dkimDir = "/var/dkim";
  dkimSelector = "default";
  dkimKeyFile = "${dkimDir}/${dkimSelector}.private";
  dkimKeyTxt = "${dkimDir}/${dkimSelector}.txt";
  dkimSocket = "8891";
  createDkimCert = domain:
    ''
      if [ ! -f "${dkimKeyFile}" ]; then
        ${pkgs.opendkim}/bin/opendkim-genkey \
          -s "${dkimSelector}" \
          -d "${domain}" \
          -D "${dkimDir}" \
          --bits="2048"
        chmod 644 "${dkimKeyTxt}"
        chmod 600 "${dkimKeyFile}"
      fi
    '';
  dkimTrustedHosts = pkgs.writeText "trusted.hosts" ''
    127.0.0.1
    localhost
    *.${mailDomain}
  '';

in

{
  users.users.noreply = {
    isSystemUser = true;
    group = "noreply";
  };
  users.groups.noreply = { };
  users.users.postfix.extraGroups = [ "opendkim" ];
  services.postfix = {
    enable = true;
    extraMasterConf = ''
      postlog unix-dgram n - n - 1 postlogd
    '';
    config = {
      maillog_file = "/var/log/postfix.log";
      maillog_file_permissions = "0644";
      inet_interfaces = "loopback-only";
      myhostname = mailDomain;
      mydomain = mailDomain;
      mydestination = "localhost.$mydomain, localhost, $myhostname";
      smtpd_milters = "inet:127.0.0.1:${dkimSocket}";
      non_smtpd_milters = "inet:127.0.0.1:${dkimSocket}";
      milter_default_action = "accept";
    };
  };
  services.opendkim = {
    enable = true;
    keyPath = dkimDir;
    domains = "csl:${mailDomain}";
    group = "opendkim";
    selector = dkimSelector;
    socket = "inet:${dkimSocket}@127.0.0.1";
    configFile = pkgs.writeText "opendkim.conf" ''
      Canonicalization    relaxed/simple
      Mode                sv
      AutoRestart         yes
      AutoRestartRate     5/1H
      SignatureAlgorithm  rsa-sha256
      UMask               002
      UserID              opendkim:opendkim
      SoftwareHeader      yes
      OversignHeaders     From
      Selector            ${dkimSelector}
      KeyFile             ${dkimKeyFile}
      ExternalIgnoreList  ${dkimTrustedHosts}
      InternalHosts       ${dkimTrustedHosts}
      Socket              inet:${dkimSocket}@127.0.0.1
    '';
  };
  systemd.services.opendkim.preStart = lib.mkForce (createDkimCert mailDomain);
}
