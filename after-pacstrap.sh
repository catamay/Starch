#!/bin/bash

#
# This script does the main installation tasks after pacstrap has been run by
# the main installer script.
#

source constants.sh
source helpers.sh

PASSWORD=

user_setup() {
    echo -e "${GREEN}Creating new user${NC}"
    useradd -m -G wheel $USERNAME
    echo ${USERNAME}:${PASSWORD} | chpasswd -e

    # Allow members of wheel group to use sudo
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
}

build_jujube() {
    echo -e "${GREEN}Building Jujube${NC}"
    begin_checked_section

    git clone --depth=1 https://gitlab.com/square-game-liberation-front/jujube.git /jujube
    mkdir /jujube/build
    pushd /jujube
    pushd build
    meson setup .. \
        --prefix=/opt \
        --buildtype=Release \

    ninja 
    popd
    meson --install build --strip
    popd
    rm -rf /jujube
    chown -R ${USERNAME}:${USERNAME} /opt/jujube-1.1/

    end_checked_section
}

configure_settings() {
#     echo -e "${GREEN}Setting up configuration files${NC}"
#     begin_checked_section

#     # Set initial configuration for jujube
#     mkdir -p /opt/stepmania-1.1/Data
#     cat <<EOF >> /opt/stepmania-1.1/Data/Static.ini
# [Options]
# Windowed=0
# EOF
#     chown ${USERNAME}:${USERNAME} /opt/stepmania-5.1/Data/Static.ini

    # Run jujube when `startx` is run
    cat <<EOF > /home/${USERNAME}/.xinitrc
#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "\$f" ] && . "\$f"
  done
  unset f
fi

exec /opt/jujube-1.1/jujube
EOF
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.xinitrc

    # Automatically login as user
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --skip-login --nonewline --noissue --autologin $USERNAME --noclear %I \$TERM
EOF

    # Start X after login on tty1
    cat <<EOF > /home/${USERNAME}/.bash_profile
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
    startx -- -nocursor &>/dev/null
fi
EOF
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.bash_profile

    # Disable `Last login...` message
    touch /home/${USERNAME}/.hushlogin
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.hushlogin

    end_checked_section
}

timezone_setup() {
    echo -e "${GREEN}Setting timezone${NC}"
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
}

locale_setup() {
    echo -e "${GREEN}Setting locale${NC}"
    echo "${LANG} UTF-8" >> /etc/locale.gen
    echo "LANG=${LANG}" >> /etc/locale.conf
    locale-gen
}

initramfs_setup() {
    echo -e "${GREEN}Rebuilding initramfs${NC}"
    begin_checked_section

    # Compress with lz4
    echo COMPRESSION=\"lz4\" >> /etc/mkinitcpio.conf
    echo COMPRESSION_OPTIONS=\"-9\" >> /etc/mkinitcpio.conf
    sed -i -e "s/^MODULES=(\(.*\))/MODULES=(\1 lz4 lz4_compress)/" /etc/mkinitcpio.conf

    if has_nvidia_gpu; then
        # Enable NVIDIA DRM kernel mode setting
        sed -i -e "s/^MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm \1)/" /etc/mkinitcpio.conf

        # If the nvidia or linux packages are updated, rebuild initramfs again
        mkdir -p /etc/pacman.d/hooks
        cat <<EOF > /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux

[Action]
Description=Update Nvidia module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF
    fi

    # Replace udev with systemd
    sed -i -e "s/HOOKS=(\(.*\)\(udev\)/HOOKS=(\1systemd/" /etc/mkinitcpio.conf

    # Rebuild initramfs
    mkinitcpio -p linux

    end_checked_section
}

bootloader_setup() {
    echo -e "${GREEN}Setting up bootloader${NC}"
    begin_checked_section

    bootctl install
    local uuid=$(cat $UUID_PATH)
    cat <<EOF > /boot/loader/loader.conf
timeout 0
default arch
EOF

    # options:
    # - nvidia-drm.modeset=1: Enable KMS in NVIDIA driver
    # - quiet rd.udev.log_priority=3: Disable most messages from appearing
    if has_nvidia_gpu; then
        local nvidia_drm="nvidia-drm.modeset=1"
    fi

    cat <<EOF > /boot/loader/entries/arch.conf
title ArchLinux
linux /vmlinuz-linux
initrd ${CPU_VENDOR}-ucode.img
initrd /initramfs-linux.img
options root=${uuid} rw ${nvidia_drm} quiet rd.udev.log_priority=3
EOF

    # Hack to remove the "SHA256 Validated" message from appearing at every
    # boot by replacing the call to `Print()` with nops. This will only be
    # applied to versions matching the following checksums:
    local checksums=(
        # 243.78-1
        "b562dceb4622989ecfbb52acdabd804470f47d7acf4e45687bede7fb33926938"
        # 243.78-2
        "9e50bb64f1adf79ae73c8e171287e92ff3cb462237743eb94a02a0286591028a"
    )
    local filenames=(
        "/boot/EFI/BOOT/BOOTX64.EFI"
        "/boot/EFI/systemd/systemd-bootx64.efi"
    )
    local patch="\x90\x90\x90\x90\x90"
    for checksum in "${checksums[@]}"; do for filename in "${filenames[@]}"; do
        if [[ "$(sha256sum ${filename} | cut -d' ' -f1)" == "$checksum" ]]; then
            echo -ne $patch | \
                dd of=${filename} bs=1 seek=40320 count=5 conv=notrunc
        fi
    done; done

    end_checked_section
}

cleanup() {
    echo -e "${GREEN}Cleaning up${NC}"
    rm -rf /var/cache/pacman/pkg
    touch /tmp/success
}

# Parse arguments
while [[ "$1" != "" ]]; do
    case $1 in
        --password ) shift; PASSWORD=$1 ;;
        * ) echo "Invalid argument \"$1\""; exit 1 ;;
    esac
    shift
done

user_setup
build_jujube
configure_settings
timezone_setup
locale_setup
initramfs_setup
bootloader_setup
cleanup