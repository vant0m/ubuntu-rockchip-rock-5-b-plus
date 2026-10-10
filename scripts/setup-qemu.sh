#!/bin/bash

# Make sure arm64 binaries from recent Ubuntu releases run in a chroot.
#
# Recent releases use syscalls (openat2, fchmodat2) that QEMU only emulates
# since version 9.1, while Ubuntu 24.04 ships QEMU 8.2. Suites needing a
# newer QEMU set QEMU_MIN_VERSION. When the host QEMU is older, take the
# static qemu-aarch64 from Ubuntu 26.04 and register it with binfmt_misc
# next to the host one. The newest registration wins, and registrations do
# not survive a reboot, so the host setup is left untouched.
#
# Older releases keep the host QEMU: apt from Ubuntu 22.04 can fail with
# ENOMEM under QEMU 10, so a registration left by a previous build of a
# newer release is removed.

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

case "$(uname -m)" in
    aarch64)
        # Native build, no emulation needed
        exit 0
        ;;
    x86_64)
        ;;
    *)
        echo "Warning: unsupported host architecture $(uname -m), not setting up QEMU"
        exit 0
        ;;
esac

entry=/proc/sys/fs/binfmt_misc/qemu-aarch64-ubuntu-rockchip

version="$(qemu-aarch64-static --version 2> /dev/null | sed -n 's/^qemu-aarch64 version \([0-9]*\.[0-9]*\).*/\1/p')"
if [ -z "${QEMU_MIN_VERSION}" ] || { [ -n "${version}" ] && dpkg --compare-versions "${version}" ge "${QEMU_MIN_VERSION}"; }; then
    if [ -e "${entry}" ]; then
        echo -1 > "${entry}"
    fi
    exit 0
fi

if [ ! -e /proc/sys/fs/binfmt_misc/register ]; then
    mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
fi

qemu="$(readlink -f qemu)/qemu-aarch64-static"
if [ ! -x "${qemu}" ]; then
    deb="$(../scripts/download-from-archive.sh resolute universe/binary-amd64/Packages qemu-user qemu)"
    dpkg-deb --fsys-tarfile "${deb}" | tar -x -O ./usr/bin/qemu-aarch64 > "${qemu}.tmp"
    chmod 755 "${qemu}.tmp"
    mv "${qemu}.tmp" "${qemu}"
    rm -f "${deb}"
fi

# Register again even if already there, so it stays the newest registration
if [ -e "${entry}" ]; then
    echo -1 > "${entry}"
fi

magic='\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'
mask='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
echo ":qemu-aarch64-ubuntu-rockchip:M::${magic}:${mask}:${qemu}:POF" > /proc/sys/fs/binfmt_misc/register

echo "Using $("${qemu}" --version | head -n1) to run arm64 binaries (host has ${version:-no QEMU})"
