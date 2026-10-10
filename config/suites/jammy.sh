# shellcheck shell=bash

export RELASE_NAME="Ubuntu 22.04 LTS (Jammy Jellyfish)"
export RELASE_VERSION="22.04"

export KERNEL_TYPE="vendor"
# The kernel packages take their dependencies from the host libraries, so
# the kernel must be built on the same Ubuntu release
export KERNEL_BUILD_HOST="jammy"
export KERNEL_REPO="https://github.com/Joshua-Riek/linux-rockchip.git"
export KERNEL_BRANCH="jammy"
export KERNEL_FLAVOR="rockchip"

export EXTRA_PPAS="jjriek/rockchip jjriek/rockchip-multimedia"
