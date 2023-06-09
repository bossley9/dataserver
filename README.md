# dataserver

A NixOS configuration for my data server

## About

This configuration is designed for a remote data VPS on Vultr.

## Installation

1. Go to [https://channels.nixos.org](https://channels.nixos.org) to find the latest stable minimal x86_64 ISO url.
2. Deploy a server in Vultr using the custom ISO link from earlier. I chose a Cloud Compute plan with AMD High Performance, 1 vCPU and 1 GB RAM, and auto backups disabled.
3. Log into the web console and copy over ssh keys to perform the rest of the installation via ssh.
    ```sh
    mkdir ~/.ssh
    curl -L https://github.com/YOUR_USERNAME.keys > ~/.ssh/authorized_keys
    ```
    The following steps can now be performed via SSH (`ssh nixos@ip`).
4. Log into root and set up packages.
    ```sh
    sudo -i
    nix-shell -p git
    set -o vi
5. Partition the disk, where the swap is the same size as allocated RAM. MBR partitioning is required or the VPS may not recognize any bootable partitions.
    ```sh
    parted /dev/vda -- mklabel msdos
    parted /dev/vda -- mkpart primary 1MB -2GB
    parted /dev/vda -- mkpart primary linux-swap -2GB 100%
    ```
6. Format each partition. I recommend ext4 over btrfs because a VPS generally doesn't need CoW or snapshot features, and ext4 is slightly faster and uses less storage.
    ```sh
    mkfs.ext4 -L main /dev/vda1
    mkswap -L swap /dev/vda2
    swapon /dev/vda2
    mount /dev/disk/by-label/main /mnt
    ```
7. Generate a configuration derived from hardware if you're starting from scratch without this repository.
    ```sh
    nixos-generate-config --root /mnt
    ```
8. Clone this configuration and move files into the appropriate locations. Be sure to double check the hardware configuration for descrepancies.
9. Copy SSH public keys for server access. **If you do not do this, you will be locked out of the server.**
    ```sh
    cp /home/nixos/.ssh/authorized_keys /mnt/etc/nixos/keys.pub
    ```
10. Install the operating system.
    ```sh
    nixos-install --no-root-passwd --flake .#dataserver
    ```
11. In the Vultr dashboard, remove the custom ISO. This will trigger a VPS reboot. Then verify you can access the server via SSH (`ssh nixos@ip`).
12. Make sure to port 25 is unblocked on the VPS or server you are using. For example, Vultr blocks port 25 on all instances by default and will only unblock the port after submitting support request.
