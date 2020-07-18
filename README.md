# arch linux installation

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
    wifi-menu
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
        (fdisk) +256M
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

1. Create the encrypted partition and open it

    ```bash
    cryptsetup --verify-passphrase luksFormat /dev/sda2 --type luks1 --cipher aes-xts-plain64 -s 512 -h sha512 --iter-time 500 --key-slot 1
    cryptsetup luksOpen /dev/sda2 cryptroot
    ```

1. Create an encryption key for grub (so the passphrase isn't prompted twice) and put it on slot 0 for added boot speed

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
