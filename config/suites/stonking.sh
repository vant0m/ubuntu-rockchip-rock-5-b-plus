# shellcheck shell=bash

export RELASE_NAME="Ubuntu 26.10 (Stonking Stingray)"
export RELASE_VERSION="26.10"

# Mainline suites use the generic kernel from the Ubuntu archive, which
# already ships the RK3588 drivers and device trees, and mainline U-Boot.
export KERNEL_TYPE="mainline"
export KERNEL_FLAVOR="generic"

# Running arm64 binaries of this release under emulation needs QEMU >= 9.1
export QEMU_MIN_VERSION="9.1"

export EXTRA_PPAS=""
