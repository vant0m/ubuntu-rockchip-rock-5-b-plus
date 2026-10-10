# shellcheck shell=bash

export RELASE_NAME="Ubuntu 25.04 (Plucky Puffin)"
export RELASE_VERSION="25.04"

export KERNEL_TYPE="vendor"
# The kernel packages take their dependencies from the host libraries, so
# the kernel must be built on the same Ubuntu release
export KERNEL_BUILD_HOST="plucky"
export KERNEL_REPO="https://github.com/Joshua-Riek/linux-rockchip.git"
export KERNEL_BRANCH="plucky"
export KERNEL_FLAVOR="rockchip"

export EXTRA_PPAS="jjriek/rockchip"
