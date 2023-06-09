# Send-only postfix mail server for password reset and notification emails, mostly.
# First, set up DNS records:
# TXT xxx.xx.xxx.xx v=spf1 ip4:xxx.xx.xxx.xx ip6:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx ~all
#
# To test mail delivery with sendmail:
# printf "Subject: Hello World\nThis is a test email." | sendmail your@email.com

{ config, pkgs, ... }:

{
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
