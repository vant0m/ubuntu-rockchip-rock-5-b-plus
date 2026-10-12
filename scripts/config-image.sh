#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/boards/${BOARD}.sh"

if [[ -z ${SUITE} ]]; then
    echo "Error: SUITE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/suites/${SUITE}.sh"

if [[ -z ${FLAVOR} ]]; then
    echo "Error: FLAVOR is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/flavors/${FLAVOR}.sh"

# Find the newest deb matching a pattern in a build directory
find_deb() {
    local dir="$1"
    local pattern="$2"
    local deb

    deb="$(find "${dir}" -maxdepth 1 -name "${pattern}" 2> /dev/null | sort | tail -n1)"
    if [ ! -e "${deb}" ]; then
        echo "Error: could not find ${pattern} in build/${dir}" >&2
        exit 1
    fi
    echo "${deb}"
}

if [[ ${LAUNCHPAD} != "Y" ]]; then
    uboot_deb="$(find_deb "${UBOOT_PACKAGE}" "u-boot-${BOARD}_*.deb")"

    if [[ ${KERNEL_TYPE} == "vendor" ]]; then
        # Kernel packages are built per suite in build/kernel-${SUITE}
        kernel_packages=(
            "$(find_deb "kernel-${SUITE}" 'linux-image-*.deb')"
            "$(find_deb "kernel-${SUITE}" 'linux-headers-*.deb')"
            "$(find_deb "kernel-${SUITE}" 'linux-modules-*.deb')"
            "$(find_deb "kernel-${SUITE}" 'linux-buildinfo-*.deb')"
            "$(find_deb "kernel-${SUITE}" 'linux-rockchip-headers-*.deb')"
        )
    fi
fi

setup_mountpoint() {
    local mountpoint="$1"

    if [ ! -c /dev/mem ]; then
        mknod -m 660 /dev/mem c 1 1
        chown root:kmem /dev/mem
    fi

    mount dev-live -t devtmpfs "$mountpoint/dev"
    mount devpts-live -t devpts -o nodev,nosuid "$mountpoint/dev/pts"
    mount proc-live -t proc "$mountpoint/proc"
    mount sysfs-live -t sysfs "$mountpoint/sys"
    mount securityfs -t securityfs "$mountpoint/sys/kernel/security"
    # Provide more up to date apparmor features, matching target kernel
    # cgroup2 mount for LP: 1944004
    mount -t cgroup2 none "$mountpoint/sys/fs/cgroup"
    mount -t tmpfs none "$mountpoint/tmp"
    mount -t tmpfs none "$mountpoint/var/lib/apt/lists"
    mount -t tmpfs none "$mountpoint/var/cache/apt"
    mv "$mountpoint/etc/resolv.conf" resolv.conf.tmp
    cp /etc/resolv.conf "$mountpoint/etc/resolv.conf"
    mv "$mountpoint/etc/nsswitch.conf" nsswitch.conf.tmp
    sed 's/systemd//g' nsswitch.conf.tmp > "$mountpoint/etc/nsswitch.conf"
}

teardown_mountpoint() {
    # Reverse the operations from setup_mountpoint
    local mountpoint
    mountpoint=$(realpath "$1")

    # ensure we have exactly one trailing slash, and escape all slashes for awk
    mountpoint_match=$(echo "$mountpoint" | sed -e's,/$,,; s,/,\\/,g;')'\/'
    # sort -r ensures that deeper mountpoints are unmounted first
    awk </proc/self/mounts "\$2 ~ /$mountpoint_match/ { print \$2 }" | LC_ALL=C sort -r | while IFS= read -r submount; do
        mount --make-private "$submount"
        umount "$submount"
    done
    mv resolv.conf.tmp "$mountpoint/etc/resolv.conf"
    mv nsswitch.conf.tmp "$mountpoint/etc/nsswitch.conf"
}

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Override localisation settings to address a perl warning
export LC_ALL=C

# Debootstrap options
chroot_dir=rootfs
overlay_dir=../overlay

# Extract the compressed root filesystem
rm -rf ${chroot_dir} && mkdir -p ${chroot_dir}
tar -xpJf "ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz" -C ${chroot_dir}

# Mount the root filesystem
setup_mountpoint $chroot_dir

# Update packages. apt from 22.04 sometimes fails to read the indexes with
# ENOMEM under emulation, so try again before giving up
for attempt in 1 2 3; do
    if chroot $chroot_dir apt-get update; then
        break
    elif [ "${attempt}" -eq 3 ]; then
        echo "Error: apt-get update failed"
        exit 1
    fi
    echo "Warning: apt-get update failed, trying again"
done
chroot $chroot_dir apt-get -y upgrade
    
# Run config hook to handle board specific changes
if [[ $(type -t config_image_hook__"${BOARD}") == function ]]; then
    config_image_hook__"${BOARD}" "${chroot_dir}" "${overlay_dir}" "${SUITE}"
fi 

# Download and install U-Boot
if [[ ${LAUNCHPAD} == "Y" ]]; then
    chroot ${chroot_dir} apt-get -y install "u-boot-${BOARD}"
else
    cp "${uboot_deb}" ${chroot_dir}/tmp/
    chroot ${chroot_dir} apt-get -y install "/tmp/$(basename "${uboot_deb}")"
    chroot ${chroot_dir} apt-mark hold "$(dpkg-deb -f "${uboot_deb}" Package)"

    if [[ ${KERNEL_TYPE} == "vendor" ]]; then
        # Replace the kernel from the rootfs with the one we built
        cp "${kernel_packages[@]}" ${chroot_dir}/tmp/
        chroot ${chroot_dir} /bin/bash -c "apt-get -y purge \$(dpkg --list | grep -Ei 'linux-image|linux-headers|linux-modules|linux-rockchip' | awk '{ print \$2 }')"
        # shellcheck disable=SC2046
        chroot ${chroot_dir} dpkg -i $(for deb in "${kernel_packages[@]}"; do echo "/tmp/$(basename "${deb}")"; done)
        for deb in "${kernel_packages[@]}"; do
            chroot ${chroot_dir} apt-mark hold "$(dpkg-deb -f "${deb}" Package)"
        done
    fi
fi

# Update the initramfs
chroot ${chroot_dir} update-initramfs -u

# Remove packages
chroot ${chroot_dir} apt-get -y clean
chroot ${chroot_dir} apt-get -y autoclean
chroot ${chroot_dir} apt-get -y autoremove

# The board has no battery for its clock by default: systemd starts the
# clock at least at the mtime of this file, the build time of the image,
# instead of its own build time, which can be months earlier
touch "${chroot_dir}/usr/lib/clock-epoch"

# Umount the root filesystem
teardown_mountpoint $chroot_dir

# Compress the root filesystem and then build a disk image
cd ${chroot_dir} && tar -cpf "../ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64-${BOARD}.rootfs.tar" . && cd .. && rm -rf ${chroot_dir}
../scripts/build-image.sh "ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64-${BOARD}.rootfs.tar"
rm -f "ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64-${BOARD}.rootfs.tar"
