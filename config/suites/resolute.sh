# shellcheck shell=bash

export RELASE_NAME="Ubuntu 26.04 LTS (Resolute Raccoon)"
export RELASE_VERSION="26.04"

# Mainline suites use the generic kernel from the Ubuntu archive, which
# already ships the RK3588 drivers and device trees, and mainline U-Boot.
# 26.04 follows its hardware enablement (HWE) kernel: the same 7.0 as
# linux-generic for now, then the kernels of the next Ubuntu releases as
# Canonical publishes them for 26.04, starting with 7.3 from 26.10.
export KERNEL_TYPE="mainline"
export KERNEL_FLAVOR="generic-hwe-26.04"

# Running arm64 binaries of this release under emulation needs QEMU >= 9.1
export QEMU_MIN_VERSION="9.1"

export EXTRA_PPAS=""
