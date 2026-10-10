# shellcheck shell=bash

export RELASE_NAME="Ubuntu 24.10 (Oracular Oriole)"
export RELASE_VERSION="24.10"

export KERNEL_TYPE="vendor"
# The kernel packages take their dependencies from the host libraries, so
# the kernel must be built on the same Ubuntu release
export KERNEL_BUILD_HOST="oracular"
export KERNEL_REPO="https://github.com/Joshua-Riek/linux-rockchip.git"
export KERNEL_BRANCH="oracular"
export KERNEL_FLAVOR="rockchip"

export EXTRA_PPAS="jjriek/rockchip"
