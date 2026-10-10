# shellcheck shell=bash

export RELASE_NAME="Ubuntu 24.04 LTS (Noble Numbat)"
export RELASE_VERSION="24.04"

export KERNEL_TYPE="vendor"
# The kernel packages take their dependencies from the host libraries, so
# the kernel must be built on the same Ubuntu release
export KERNEL_BUILD_HOST="noble"
export KERNEL_REPO="https://github.com/Joshua-Riek/linux-rockchip.git"
export KERNEL_BRANCH="noble"
export KERNEL_FLAVOR="rockchip"

# dpkg hangs in a noble chroot under QEMU 8.2 from Ubuntu 24.04
export QEMU_MIN_VERSION="9.1"

export EXTRA_PPAS="jjriek/rockchip jjriek/rockchip-multimedia"
