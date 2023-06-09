# Send-only postfix mail server for password reset and notification emails, mostly.
# First, set up DNS records:
# TXT subdomain "v=spf1 ip4:xxx.xx.xxx.xx ip6:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx ~all"
# TXT _dmarc.subdomain "v=DMARC1; p=reject; pct=100"
# MX subdomain 0 subdomain.domain.com
#
# To test mail delivery with sendmail:
# printf "Subject: Hello World\nThis is a test email." | sendmail your@email.com

{ config, pkgs, ... }:

let
  mailDomain = "mail.bossley.us";
in

{
  users.users.noreply = {
    isSystemUser = true;
    group = "noreply";
  };
  users.groups.noreply = { };
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
    };
  };
}
