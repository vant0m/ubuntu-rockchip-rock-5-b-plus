# shellcheck shell=bash

export RELASE_NAME="Ubuntu 26.10 (Stonking Stingray)"
export RELASE_VERSION="26.10"

# Mainline suites use the generic kernel from the Ubuntu archive, which
# already ships the RK3588 drivers and device trees, and mainline U-Boot.
export KERNEL_TYPE="mainline"
export KERNEL_FLAVOR="generic"

export EXTRA_PPAS=""
