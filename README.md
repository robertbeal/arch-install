# arch linux installation

The steps I use to get an intial install of Arch Linux. It includes both BIOS/MBR and UEFI/GPT steps as I've got a mixture of old and new hardware.

It will create an installation with block device device encryption (aside from the boot partition) using LVM on LUKS (via `dm-crypt)`. The boot partition can be better secured using UEFI if you're able to sign the bootloader.

## Additional Files

- `sshd_config` - a hardened, production grade OpenSSH example config
- `sysctl.conf` - tweaked kernel settings for better security

## Assumptions

The guide assumes that `/dev/sda` is the system disk

## Steps

1. Boot up the arch installer
1. Change to UK keyboard (arch defaults to US)

    ```bash
    loadkeys uk
    ```

1. If wifi connection is needed

    ```bash
    iwctl
    [iwd]> station $device connect $ssid
    ```

1. BIOS/MBR based install

    1. `fdisk /dev/sda`
    1. Create an MBR partition table

        ```bash
        (fdisk) o
        ```

    1. Creates two paritions, `boot` and `root`

        ```bash
        (fdisk) n
        (fdisk) p
        (fdisk) 1
        (fdisk) <Enter>
        (fdisk) +500M
        (fdisk) t
        (fdisk) 83

        (fdisk) n
        (fdisk) p
        (fdisk) 2
        (fdisk) <Enter>
        (fdisk) <Enter>
        (fdisk) t
        (fdisk) 83
        ```

    1. Format the `boot` partition

        ```bash
        mkfs.ext2 /dev/sda1
        ```

1. UEFI/GPT based install

    1. Create the partitions

        ```bash
        cgdisk /dev/sdx
        1 500MB EFI partition # Hex code = ef
        2 100% / partition        # Hex code = 83
        ```

    1. Format the `boot` partition

        ```bash
        mkfs.fat -F32 /dev/sda1
        ```

1. Create the encrypted partition and open it

    ```bash
    cryptsetup --verify-passphrase luksFormat /dev/sda2 --type luks1 --cipher aes-xts-plain64 -s 512 -h sha512 --iter-time 500 --key-slot 1
    cryptsetup luksOpen /dev/sda2 cryptroot
    ```

1. Create an encryption key for grub (so the passphrase isn't prompted twice) and put it on slot 0 for added boot speed. Note this does improve convenience at the cost of security as the key becomes a point of weakness

    ```bash
    dd if=/dev/urandom of=/keyfile.bin bs=1024 count=4
    chmod 000 /keyfile.bin
    cryptsetup luksAddKey /dev/sda2 /keyfile.bin --key-slot 0
    ```

1. Create the logical volumes inside the encrypted partition

    ```bash
    pvcreate /dev/mapper/cryptroot
    vgcreate system /dev/mapper/cryptroot
    lvcreate --size 16G system --name swap
    lvcreate -l +100%FREE system --name root
    ```

1. Create the filesystems on encrypted partitions

    ```bash
    mkfs.ext4 /dev/mapper/system-root
    mkswap /dev/mapper/system-swap
    ```

1. Mount the partitions

    ```bash
    mount /dev/mapper/system-root /mnt
    swapon /dev/mapper/system-swap
    # UEFI/GPT
    mkdir -p /mnt/boot/efi
    mount /dev/sda1 /mnt/boot/efi
    # BIOS/MBR
    mkdir -p /mnt/boot
    mount /dev/sda1 /mnt/boot
    ```

1. Install base system

    ```bash
    pacstrap /mnt \
        base \
        base-devel \
        bash \
        vim
    # UEFI/GPT
    pacstrap /mnt \
        efibootmgr \
        grub-efi-x86_64
    # BIOS/MBR
    pacstrap /mnt \
        grub-bios
    ```

1. Generate fstab. For SSD's change `relatime` on all non-boot partitions to `noatime` to reduce wear

    ```bash
    genfstab -pU /mnt >/mnt/etc/fstab
    ```

1. Copy the Grub crypto key into the root partition

    ```bash
    cp /keyfile.bin /mnt
    ```

1. Enter the new system

    ```bash
    arch-chroot /mnt /bin/bash
    ```

1. Set locale

    ```bash
    vim /etc/locale.gen # uncomment any locales needed, ie en_GB.UTF-8
    locale-gen
    echo LANG=en_GB.UTF-8 >/etc/locale.conf
    ```

1. Set the default paper size

    ```bash
    echo a4 > /etc/papersize
    ```

1. Install base packages

    ```bash
    pacman -S \
        dialog \
        gnome-terminal \
        linux \
        linux-firmware \
        lvm2 \
        mesa \
        sudo \
        wpa_supplicant \
        xorg-server
    ```

1. mkinitcpio

    ```bash
    vim /etc/mkinitcpio.conf
    ## Add 'keyboard keymap' to HOOKS before 'block'
    ## Add 'encrypt lvm2' to HOOKS before 'filesystems'
    sed -i 's\^FILES=.*\FILES="/keyfile.bin"\g' /etc/mkinitcpio.conf
    mkinitcpio -p linux
    ```

1. grub

    ```bash
    vim /etc/default/grub
    # GRUB_HIDDEN_TIMEOUT=0
    # GRUB_HIDDEN_TIMEOUT_QUIET=true
    # GRUB_ENABLE_CRYPTODISK=y
    # GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda2:cryptroot root=/dev/mapper/system-root"
    # GRUB_CMDLINE_LINUX="cryptdevice=UUID=...:cryptroot root=UUID=..."

    # UEFI/GPT
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Arch"
    # BIOS/MBR
    grub-install --target=i386-pc /dev/sda

    grub-mkconfig -o /boot/grub/grub.cfg
    ```

1. Create users

    ```bash
    useradd --create-home --user-group --group wheel rob
    passwd rob
    ```

1. Enable `wheel` group

    ```bash
    sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers
    ```

1. Set hostname

    ```bash
    echo "robs-machine" >/etc/hostname
    echo "127.0.1.1 robs-machine.localdomain    robs-machine" >> /etc/hosts
    ```

1. System clock

    ```bash
    ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
    hwclock --systohc --utc
    ```

1. NTP

    ```bash
    pacman -S --noconfirm ntp
    systemctl enable ntpd
    ```

1. Hardening

    ```bash
    # disable root password
    passwd -l root
    # reduce permissions on sensitive files
    chmod 700 /boot /etc/iptables
    ```

1. Entropy services

    ```bash
    pacman -S --noconfirm rng-tools haveged
    systemctl enable haveged
    systemctl enable rngd
    ```

1. Pacman

    ```bash
    pacman -S --noconfirm pacman-contrib
    systemctl enable paccache.timer
    ```

1. Systemd

    ```
    systemctl enable systemd-homed
    ```

1. Login

    ```bash
    pacman -S lightdm lightdm-gtk-greeter
    systemctl enable lightdm
    ```

1. Desktop

    ```bash
    pacman -S cinnamon nemo-fileroller nemo-preview
    ```

1. NetworkManager

    ```bash
    pacman -S networkmanager gnome-keyring
    pacman -S --noconfirm dnsmasq networkmanager-openvpn network-manager-applet libsecret
    echo "[main]
    dns=dnsmasq" | sudo tee /etc/NetworkManager/NetworkManager.conf
    systemctl enable NetworkManager
    ```

1. Clean up and reboot

    ```bash
    exit
    umount -R /mnt
    swapoff -a
    ```

[Next Steps...](./NEXT.md)
