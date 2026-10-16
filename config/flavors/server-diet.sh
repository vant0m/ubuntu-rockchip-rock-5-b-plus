# shellcheck shell=bash

# The server image without what a headless server does not need, see
# scripts/diet-image.sh. It is made from the root filesystem of the server
# flavor, and only for the releases on the Ubuntu kernel.
export PROJECT=ubuntu-cpc
export ROOTFS_FLAVOR=server
export FLAVOR_KERNEL_TYPES="mainline"
export DIET=y
