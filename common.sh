#!/bin/bash

# kernel hardening
cat sysctl.conf | sudo tee /etc/sysctl.d/51-net.conf

# dock + theme
sudo pacman -S --noconfirm \
    arc-gtk-theme \
    elementary-icon-theme \
    plank \
    rofi

# firewall
sudo pacman -S --noconfirm ufw ufw-extras
sudo systemctl enable ufw.service
sudo ufw --force reset
sudo ufw allow ntp
sudo ufw --force default deny incoming
sudo ufw --force default allow outgoing
sudo ufw --force enable

# common system apps
sudo pacman -S --noconfirm \
    bind-tools \
    code \
    cronie \
    dconf-editor \
    dosfstools \
    fakeroot \
    gparted \
    net-tools \
    openssh \
    patch

# gnome apps
sudo pacman -S --noconfirm \
    eog \
    evince \
    gedit \
    gnome-packagekit \
    gnome-calculator \
    gnome-screenshot \
    gthumb \
    rhythmbox

# entropy
sudo pacman -S --noconfirm rng-tools haveged
sudo systemctl enable haveged
sudo systemctl enable rngd

# dev
sudo pacman -S --noconfirm \
    curl \
    git \
    jq \
    shellcheck \
    stow \
    tmux \
    vim \
    zsh

# web
sudo pacman -S --noconfirm \
    firefox \
    chromium \
    mpv

# office
sudo pacman -S --noconfirm \
    libreoffice-fresh \
    mythes-en \
    hyphen-en \
    hyphen \
    libmythes

# android
sudo pacman -S --noconfirm \
    libmtp \
    mtpfs \
    android-udev \
    android-tools \
    gvfs \
    gvfs-mtp

# fonts
## dejavu
sudo pacman -S --noconfirm ttf-dejavu ttf-liberation noto-fonts &&
sudo ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d &&
sudo ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d &&
sudo ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d &&
sudo sed -i 's/^#export FREETYPE_PROPERTIES/export FREETYPE_PROPERTIES/' /etc/profile.d/freetype2.sh &&
cat fontconfig.xml | sudo tee /etc/fonts/local.conf &&
## msfonts
curl -L https://github.com/robertbeal/msfonts/raw/master/install.sh | sudo sh &&
## google fonts
curl https://raw.githubusercontent.com/qrpike/Web-Font-Load/master/install.sh | bash;

# network manager
sudo pacman -S --noconfirm dnsmasq networkmanager-openvpn network-manager-applet libsecret
echo "[main]
dns=dnsmasq" | sudo tee /etc/NetworkManager/NetworkManager.conf

# printing
sudo pacman -S --noconfirm cups cups-pdf system-config-printer gtk3-print-backends ghostscript gsfonts gutenprint
sudo pacman -S --noconfirm hplip
sudo systemctl enable org.cups.cupsd.service
sudo systemctl start org.cups.cupsd.service
sudo groupadd printadmin
sudo usermod -aG printadmin "$USER"
sudo sed -i "/SystemGroup sys root$/c\SystemGroup sys root printadmin" /etc/cups/cups-files.conf

# syncthing
sudo pacman -S --noconfirm syncthing syncthing-gtk
systemctl enable syncthing --user

# settings
gsettings set org.cinnamon.desktop.wm.preferences theme 'Arc Dark'
gsettings set org.cinnamon.settings-daemon.peripherals.touchpad natural-scroll false
gsettings set org.cinnamon.settings-daemon.peripherals.touchpad tap-to-click true
gsettings set org.cinnamon.desktop.wm.preferences num-workspaces 3
gsettings set org.nemo.preferences default-folder-viewer 'list-view'
gsettings set org.cinnamon.settings-daemon.plugins.power idle-dim-time 90
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 1800
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 600
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 300
gsettings set org.cinnamon.settings-daemon.plugins.power idle-brightness 10
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'
gsettings set org.gnome.nm-applet disable-disconnected-notifications true
gsettings set org.gnome.nm-applet disable-vpn-notifications true
gsettings set org.gnome.nm-applet disable-connected-notifications true
gsettings set org.gnome.nm-applet suppress-wireless-networks-available true
gsettings set org.gnome.gedit.preferences.editor scheme 'oblivion'

# ssh permissions
chmod 0700 ~/.ssh
find ~/.ssh -type d -exec chmod 0700 {} +
find ~/.ssh -type f -exec chmod 0600 {} +
chmod -R 0644 ~/.ssh/*.pub

