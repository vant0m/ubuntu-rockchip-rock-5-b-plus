#!/bin/bash

# Print the GitHub Actions build matrices for the ROCK 5B+ as key=value
# lines, meant to be appended to $GITHUB_OUTPUT.
#
# Usage: matrix.sh [SUITES] [FLAVORS]
#   SUITES and FLAVORS are space separated lists, empty means every suite
#   or flavor the board config declares as compatible.

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ../..

board="rock-5b-plus"
wanted_suites="$1"
wanted_flavors="$2"

COMPATIBLE_SUITES=()
COMPATIBLE_FLAVORS=()
# shellcheck source=/dev/null
source "config/boards/${board}.sh"

contains() {
    local list="$1"
    local item="$2"

    [ -z "${list}" ] || [[ " ${list} " == *" ${item} "* ]]
}

images=""
kernels=""
for suite in "${COMPATIBLE_SUITES[@]}"; do
    contains "${wanted_suites}" "${suite}" || continue

    unset KERNEL_TYPE KERNEL_BUILD_HOST
    # shellcheck source=/dev/null
    source "config/suites/${suite}.sh"

    # The kernel must be built on the same Ubuntu release as the suite. The
    # 22.04 rootfs and images are built on 22.04 too: its apt randomly fails
    # with ENOMEM when emulated on a 24.04 host.
    case "${KERNEL_BUILD_HOST}" in
        jammy) runner="ubuntu-22.04" ;;
        noble|"") runner="ubuntu-24.04" ;;
        *)
            echo "Error: no GitHub runner for Ubuntu ${KERNEL_BUILD_HOST}" >&2
            exit 1
            ;;
    esac

    if [[ ${KERNEL_TYPE} == "vendor" ]]; then
        kernels+="{\"suite\":\"${suite}\",\"runner\":\"${runner}\"},"
    fi

    for flavor in "${COMPATIBLE_FLAVORS[@]}"; do
        contains "${wanted_flavors}" "${flavor}" || continue
        images+="{\"board\":\"${board}\",\"suite\":\"${suite}\",\"flavor\":\"${flavor}\",\"version\":\"${RELASE_VERSION}\",\"kernel_type\":\"${KERNEL_TYPE}\",\"runner\":\"${runner}\"},"
    done
done

if [ -z "${images}" ]; then
    echo "Error: nothing to build with suites \"${wanted_suites}\" and flavors \"${wanted_flavors}\"" >&2
    exit 1
fi

echo "images={\"include\":[${images%,}]}"
echo "kernels={\"include\":[${kernels%,}]}"
echo "has_kernels=$([ -n "${kernels}" ] && echo true || echo false)"
