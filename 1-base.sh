#!/bin/bash

# change to UK keyboard (arch defaults to US)
loadkeys uk

# connect to wifi...
wifi-menu

# create partitions
cgdisk /dev/sdx
1 100MB EFI partition # Hex code = ef00 (for EFI install), ef02 (for BIOS install)
2 100% / partition    # Hex code = 8300

# format the EFI partition
mkfs.vfat -F32 /dev/sdx1

# create the encrypted partition on partition 1
cryptsetup --verify-passphrase luksFormat /dev/sdx2 --type luks1 --cipher aes-xts-plain64 -s 512 -h sha512 --iter-time 100 --key-slot 1
# open the encrypted partition
cryptsetup luksOpen /dev/sdx2 cryptroot

# encryption key for grub (so passphrase isn't prompted twice)
# put it on slot 0 for added boot speed
dd if=/dev/urandom of=/crypto_keyfile.bin bs=1024 count=4
chmod 000 /crypto_keyfile.bin
cryptsetup luksAddKey /dev/sdx2 /crypto_keyfile.bin --key-slot 0

# logical volumes inside the encrypted partition
pvcreate /dev/mapper/cryptroot
vgcreate system /dev/mapper/cryptroot
lvcreate --size 8G system --name swap
lvcreate -l +100%FREE system --name root

# create filesystems on encrypted partitions
mkfs.ext4 /dev/mapper/system-root
mkswap /dev/mapper/system-swap

# mount /
mount /dev/mapper/system-root /mnt
swapon /dev/mapper/system-swap
# EFI
mkdir -p /mnt/boot/efi
mount /dev/sdx1 /mnt/boot/efi
# BIOS
mount /dev/sdx1 /mnt/boot

# install base system
pacstrap /mnt \
    base \
    base-devel \
    bash \
    intel-ucode

# EFI
pacstrap /mnt \
    efibootmgr \
    grub-efi-x86_64

# BIOS
pacstrap /mnt \
    grub-bios

# generate fstab
genfstab -pU /mnt >>/mnt/etc/fstab
# For SSD's change 'relatime' on all non-boot partitions to 'noatime' (reduces wear)

# copy the Grub crypto key into the root partition
cp /crypto_keyfile.bin /mnt

# enter the new system
arch-chroot /mnt /bin/bash

# locale
vim /etc/locale.gen # uncomment any locales needed, ie en_GB.UTF-8
locale-gen
echo LANG=en_GB.UTF-8 >/etc/locale.conf
echo a4 > /etc/papersize

# install base packages
pacman -S \
    dialog \
    gnome-terminal \
    linux \
    linux-firmware \
    lvm2 \
    mesa \
    nano \
    sudo \
    vim \
    wpa_supplicant \
    xf86-video-fbdev \
    xorg-server

# mkinitcpio
vim /etc/mkinitcpio.conf
## Add 'keyboard keymap' to HOOKS before 'block'
## Add 'encrypt lvm2' to HOOKS before 'filesystems'
sed -i 's\^FILES=.*\FILES="/crypto_keyfile.bin"\g' /etc/mkinitcpio.conf
mkinitcpio -p linux

# grub
vim /etc/default/grub
# GRUB_HIDDEN_TIMEOUT=5
# GRUB_HIDDEN_TIMEOUT_QUIET=true
# GRUB_ENABLE_CRYPTODISK=y
# GRUB_CMDLINE_LINUX="cryptdevice=/dev/sdx2:cryptroot root=/dev/mapper/system-root"
# GRUB_CMDLINE_LINUX="cryptdevice=UUID=...:cryptroot root=UUID=..."
# EFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Arch"
# BIOS
grub-install --target=i386-pc /dev/sdx
grub-mkconfig -o /boot/grub/grub.cfg

# users
useradd --create-home --user-group --group wheel rob && passwd rob
sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers # allow wheel group in sudoers
passwd -l root                                     # disable root password

# hostname
echo "arch-linux" >/etc/hostname

# system clock
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc --utc

# time
pacman -S --noconfirm ntp
systemctl enable ntpd

# pacman
pacman -S --noconfirm pacman-contrib
systemctl enable paccache.timer

# login
pacman -S lightdm lightdm-gtk-greeter
systemctl enable lightdm

# desktop (cinnamon)
pacman -S cinnamon nemo-fileroller nemo-preview

# networkManager
pacman -S networkmanager gnome-keyring
systemctl enable NetworkManager

### hardening
chmod 700 /boot /etc/iptables

# clean up and reboot
exit
umount -R /mnt
swapoff -a
