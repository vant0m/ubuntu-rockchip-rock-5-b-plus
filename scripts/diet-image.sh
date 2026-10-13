#!/bin/bash

# Remove from a server root filesystem what a headless server does not need,
# like DietPi or the minimal Armbian images: snapd and its seeded snaps, the
# firmware and package management daemons of desktops, the datacenter
# storage stacks, and the jobs that slow down the first boots on an SD card.
#
# Usage: diet-image.sh CHROOT

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

chroot_dir="$1"
if [ ! -d "${chroot_dir}" ]; then
    echo "Usage: $0 CHROOT"
    exit 1
fi

# shellcheck disable=SC2016
installed() {
    chroot "${chroot_dir}" dpkg-query -W -f '${db:Status-Status}\n' "$1" 2> /dev/null | grep -q '^installed$'
}

purge=(
    # Snaps, and the stub that installs the lxd snap
    snapd lxd-installer
    # Firmware updates and package management for desktops, fwupd timed out
    # at every boot on an SD card
    fwupd packagekit packagekit-tools udisks2
    # Datacenter storage: multipath, iSCSI, LVM, RAID, btrfs, XFS (its
    # weekly scrub took a minute on an SD card)
    multipath-tools open-iscsi lvm2 mdadm btrfs-progs xfsprogs
    # 4G/5G modems on the M.2 B key, install modemmanager back if needed
    modemmanager
    # Crash reports, statistics and other phoning home
    apport apport-core-dump-handler whoopsie popularity-contest pollinate
    sosreport landscape-common motd-news-config byobu
)

# What stays: removing the packages above also removes the ubuntu-server
# metapackage, and with it everything it pulled in that is not marked as
# manually installed
keep=(
    openssh-server openssh-client cloud-init netplan.io sudo chrony
    linux-generic u-boot-menu u-boot-rock-5b-plus rsync mtd-utils
    ca-certificates curl wget gnupg unattended-upgrades wpasupplicant
    python3 dracut zstd vim-tiny vim nano less htop tmux screen ethtool
    iproute2 iputils-ping bash-completion command-not-found
    ubuntu-minimal ubuntu-standard
)

# Must still be there at the end, or the image would not boot or not be
# reachable
critical=(
    openssh-server cloud-init netplan.io sudo chrony linux-generic
    u-boot-menu u-boot-rock-5b-plus systemd apt
)

to_keep=()
for package in "${keep[@]}"; do
    if installed "${package}"; then
        to_keep+=("${package}")
    fi
done
chroot "${chroot_dir}" apt-mark manual "${to_keep[@]}"

to_purge=()
for package in "${purge[@]}"; do
    if installed "${package}"; then
        to_purge+=("${package}")
    fi
done

if [ ${#to_purge[@]} -gt 0 ]; then
    echo "Removing: ${to_purge[*]}"
    chroot "${chroot_dir}" apt-get -y purge --auto-remove "${to_purge[@]}"
fi

# snapd leaves its seed and state behind
rm -rf "${chroot_dir}"/var/lib/snapd "${chroot_dir}"/snap "${chroot_dir}"/var/snap "${chroot_dir}"/var/cache/snapd

# Do not rebuild the man page index in the background after each install
echo "man-db man-db/auto-update boolean false" | chroot "${chroot_dir}" debconf-set-selections
chroot "${chroot_dir}" systemctl mask man-db.timer

# Keep the journal small on an SD card
mkdir -p "${chroot_dir}/etc/systemd/journald.conf.d"
cat > "${chroot_dir}/etc/systemd/journald.conf.d/10-diet.conf" << EOF
[Journal]
SystemMaxUse=64M
EOF

# The boot waited 2 minutes for the network without an Ethernet cable: wait
# for any interface, 30 seconds at most
mkdir -p "${chroot_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d"
cat > "${chroot_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d/10-diet.conf" << EOF
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any --timeout=30
EOF

for package in "${critical[@]}"; do
    if ! installed "${package}"; then
        echo "Error: ${package} was removed"
        exit 1
    fi
done

# shellcheck disable=SC2016
echo "Installed packages after the diet: $(chroot "${chroot_dir}" dpkg-query -W -f '${db:Status-Status}\n' | grep -c '^installed$')"
