# dataserver

A NixOS configuration for a data server

## About

This configuration is designed for a remote data server, either run locally or remotely on a VPS.

## Setup (Vultr)

1. Go to [https://channels.nixos.org](https://channels.nixos.org) to find the latest stable minimal x86_64 ISO url.
2. Deploy a server in Vultr using the custom ISO link from earlier. I chose a plan with 2 GB RAM.
3. Log into the web console and copy over ssh keys to perform the rest of the installation via ssh.
    ```sh
    mkdir ~/.ssh
    # for Github keys
    curl -L https://github.com/YOUR_USERNAME.keys > ~/.ssh/authorized_keys
    # for Sourcehut keys
    curl -L https://meta.sr.ht/~YOUR_USERNAME.keys > ~/.ssh/authorized_keys
    ```
    The following steps can now be performed via SSH.
4. Log into root via `sudo -i`. Optionally you can run `set -o vi` for vi keybindings.
5. Partition the disk, where the swap is the same size as allocated RAM. MBR partitioning is required or the VPS may not recognize any bootable partitions.
    ```sh
    parted /dev/vda -- mklabel msdos
    parted /dev/vda -- mkpart primary 1MB -2GB
    parted /dev/vda -- mkpart primary linux-swap -2GB 100%
    ```
6. Format each partition. I recommend ext4 over btrfs because a VPS generally doesn't need CoW or snapshot features, and ext4 is slightly faster and uses less storage.
    ```sh
    mkfs.ext4 -L root /dev/vda1
    mkswap -L swap /dev/vda2
    swapon /dev/vda2
    mount /dev/disk/by-label/root /mnt
    ```
7. Generate a configuration derived from hardware.
    ```sh
    nixos-generate-config --root /mnt
    ```
8. Clone this configuration and move files into the appropriate locations.
    ```sh
    git clone https://git.sr.ht/~bossley9/dataserver nixos
    mv /mnt/etc/nixos/hardware-configuration.nix nixos/
    rm -r /mnt/etc/nixos
    mv nixos /mnt/etc/
    ```
9. Create a `secrets.nix` file for server-specific details. Make sure the domains do not include protocols. On the first run, you will need to add the property `isFirstRun = true` to allow access to vault creation. **Once you have created a Bitwarden vault and all necessary other account initialization, you should remove this to disallow new vault creation.**
    ```nix
    # (inside /mnt/etc/nixos/secrets.nix)
    {
      hostname = "myhostname";
      ethInterface = "myEthInterface";
      email = "alice@doe.com"; # only required for TLS certificates
      minifluxDomain = "news.example.com";
      minifluxInitialAdminUsername = "myInitialAdminUsername";
      minifluxInitialAdminPassword = "myInitialPassword";
      feedmeDomain = "feedme.example.com";
      bitwardenDomain = "vault.example.com";
      isFirstRun = true;
    }
    ```
10. Copy SSH public keys for server access. If you do not do this, you will be locked out of the server.
    ```sh
    cp /home/nixos/.ssh/authorized_keys /mnt/etc/nixos/keys.pub
    ```
11. Install the operating system.
    ```sh
    nixos-install --no-root-passwd
    ```
12. In the Vultr dashboard, remove the custom ISO. This will trigger a VPS reboot. Then verify you can access the server as `nixos@ip` via SSH.
