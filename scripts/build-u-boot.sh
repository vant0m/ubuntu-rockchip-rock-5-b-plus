#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${UBOOT_PACKAGE} ]]; then
    echo "Error: UBOOT_PACKAGE is not set"
    exit 1
fi

# Each u-boot package gets its own directory, the debs end up in
# build/${UBOOT_PACKAGE} and the source tree in build/${UBOOT_PACKAGE}/u-boot
mkdir -p "${UBOOT_PACKAGE}" && cd "${UBOOT_PACKAGE}"

# shellcheck source=/dev/null
source ../../packages/"${UBOOT_PACKAGE}"/debian/upstream
if [ ! -d u-boot ]; then
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}" u-boot
fi
if ! git -C u-boot cat-file -e "${COMMIT}^{commit}" 2> /dev/null; then
    git -C u-boot fetch origin "${BRANCH}"
fi
git -C u-boot checkout "${COMMIT}"

# Always use the packaging from this repository, even for an existing tree
rm -rf u-boot/debian
cp -r ../../packages/"${UBOOT_PACKAGE}"/debian u-boot
cd u-boot

# Target package to build
rules=${UBOOT_RULES_TARGET},package-${UBOOT_RULES_TARGET}
if [[ -n ${UBOOT_RULES_TARGET_EXTRA} ]]; then
    rules=${UBOOT_RULES_TARGET_EXTRA},${rules}
fi

# Compile u-boot into a deb package
dpkg-source --before-build .
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc --rules-target="${rules}"
dpkg-source --after-build .

rm -f ../*.buildinfo ../*.changes
