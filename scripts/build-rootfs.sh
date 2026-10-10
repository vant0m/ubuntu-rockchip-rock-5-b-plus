#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

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

if [[ -f ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

config_dir="$(readlink -f ../config)"

pushd .

tmp_dir=$(mktemp -d)
cd "${tmp_dir}" || exit 1

if [[ ${KERNEL_TYPE} == "vendor" ]]; then
    # Clone the livecd rootfs fork
    git clone https://github.com/Joshua-Riek/livecd-rootfs
    cd livecd-rootfs || exit 1
else
    # Use the livecd-rootfs of the target release with our Rockchip tweaks,
    # the same changes the fork makes on top of the noble package
    tarball="$("${config_dir}/../scripts/download-from-archive.sh" "${SUITE}" main/source/Sources livecd-rootfs)"
    mkdir livecd-rootfs
    tar -xf "${tarball}" -C livecd-rootfs --strip-components=1
    cd livecd-rootfs || exit 1

    rm -f live-build/ubuntu-cpc/hooks.d/chroot/999-cpc-fixes.chroot
    rm -f live-build/ubuntu-cpc/hooks.d/chroot/999-ubuntu-image-customization.chroot
    touch live-build/ubuntu-cpc/hooks.d/base/series/none
    install -m 755 "${config_dir}/livecd-rootfs/020-ubuntu-rockchip-tweaks.chroot" live-build/ubuntu-cpc/hooks.d/chroot/
    install -m 755 "${config_dir}/livecd-rootfs/020-ubuntu-rockchip-tweaks.chroot" live-build/ubuntu/hooks/
fi

# Install build deps
apt-get update
apt-get build-dep . -y

# Build the package
dpkg-buildpackage -us -uc

# Install the custom livecd rootfs package
apt-get install ../livecd-rootfs_*.deb --assume-yes --allow-downgrades --allow-change-held-packages
dpkg -i ../livecd-rootfs_*.deb
apt-mark hold livecd-rootfs

rm -rf "${tmp_dir}"

popd

# The host debootstrap may not know about newer releases yet, they all use
# the same script
if [ ! -e "/usr/share/debootstrap/scripts/${SUITE}" ]; then
    ln -s gutsy "/usr/share/debootstrap/scripts/${SUITE}"
fi

# Use a live-build directory per suite and flavor, and start from a clean
# state: live-build would otherwise reuse a chroot from a previous build
mkdir -p "live-build-${SUITE}-${FLAVOR}" && cd "live-build-${SUITE}-${FLAVOR}"
lb clean --purge || true
rm -rf ./auto ./config

# Query the system to locate livecd-rootfs auto script installation path
cp -r "$(dpkg -L livecd-rootfs | grep "auto$")" auto

set +e

export ARCH=arm64
export IMAGEFORMAT=none
export IMAGE_TARGETS=none

# Populate the configuration directory for live build
lb config \
    --architecture arm64 \
    --bootstrap-qemu-arch arm64 \
    --bootstrap-qemu-static /usr/bin/qemu-aarch64-static \
    --archive-areas "main restricted universe multiverse" \
    --parent-archive-areas "main restricted universe multiverse" \
    --mirror-bootstrap "http://ports.ubuntu.com" \
    --parent-mirror-bootstrap "http://ports.ubuntu.com" \
    --mirror-chroot-security "http://ports.ubuntu.com" \
    --parent-mirror-chroot-security "http://ports.ubuntu.com" \
    --mirror-binary-security "http://ports.ubuntu.com" \
    --parent-mirror-binary-security "http://ports.ubuntu.com" \
    --mirror-binary "http://ports.ubuntu.com" \
    --parent-mirror-binary "http://ports.ubuntu.com" \
    --keyring-packages ubuntu-keyring \
    --linux-flavours "${KERNEL_FLAVOR}"

if [ "${SUITE}" == "noble" ] || [ "${SUITE}" == "jammy" ]; then
    # Pin rockchip package archives
    (
        echo "Package: *"
        echo "Pin: release o=LP-PPA-jjriek-rockchip"
        echo "Pin-Priority: 1001"
        echo ""
        echo "Package: *"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: 1001"
    ) > config/archives/extra-ppas.pref.chroot
fi

if [ "${SUITE}" == "noble" ]; then
    # Ignore custom ubiquity package (mistake i made, uploaded to wrong ppa)
    (
        echo "Package: oem-*"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: -1"
        echo ""
        echo "Package: ubiquity*"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: -1"

    ) > config/archives/extra-ppas-ignore.pref.chroot
fi

# Generic packages to install
echo "software-properties-common" > config/package-lists/my.list.chroot

if [[ ${KERNEL_TYPE} == "vendor" ]]; then
    # Snap packages to install
    (
        echo "snapd/classic=stable"
        echo "core22/classic=stable"
        echo "lxd/classic=stable"
    ) > config/seeded-snaps

    if [ "${PROJECT}" == "ubuntu" ]; then
        # Specific packages to install for ubuntu desktop
        (
            echo "ubuntu-desktop-rockchip"
            echo "oem-config-gtk"
            echo "ubiquity-frontend-gtk"
            echo "ubiquity-slideshow-ubuntu"
            echo "localechooser-data"
        ) >> config/package-lists/my.list.chroot
    else
        # Specific packages to install for ubuntu server
        echo "ubuntu-server-rockchip" >> config/package-lists/my.list.chroot
    fi
else
    # Everything comes from the Ubuntu archive: the generic kernel already
    # supports the RK3588, the extlinux menu is generated by u-boot-menu
    echo "u-boot-menu" >> config/package-lists/my.list.chroot

    if [ "${PROJECT}" == "ubuntu" ]; then
        # GNOME Initial Setup creates the first user on first boot
        (
            echo "ubuntu-desktop"
            echo "gnome-initial-setup"
        ) >> config/package-lists/my.list.chroot
    else
        echo "ubuntu-server" >> config/package-lists/my.list.chroot
    fi
fi

# Build the rootfs. Only the chroot is used, the binary stage that follows
# it can fail (the livecd-rootfs minimize-manual check), so accept a failed
# build as long as the chroot stage went all the way through.
if ! lb build; then
    if [ ! -e .build/chroot_hacks ] || ! compgen -G "chroot/boot/vmlinuz-*" > /dev/null; then
        echo "Error: the rootfs build failed"
        exit 1
    fi
    echo "Warning: lb build failed after the chroot stage, using the chroot anyway"
fi

set -eE 

# Tar the entire rootfs
(cd chroot/ &&  tar -p -c --sort=name --xattrs ./*) | xz -3 -T0 > "ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz"
mv "ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz" ../
