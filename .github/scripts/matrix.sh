#!/bin/bash

# Print the GitHub Actions build matrices for a board as key=value lines,
# meant to be appended to $GITHUB_OUTPUT.
#
# Usage: matrix.sh BOARD [SUITES] [FLAVORS]
#   SUITES and FLAVORS are space separated lists, empty means every suite
#   or flavor the board config declares as compatible.

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ../..

board="$1"
wanted_suites="$2"
wanted_flavors="$3"

if [ ! -f "config/boards/${board}.sh" ]; then
    echo "Error: \"${board}\" is an unsupported board" >&2
    exit 1
fi

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

    # shellcheck source=/dev/null
    source "config/suites/${suite}.sh"

    if [[ ${KERNEL_TYPE} == "vendor" ]]; then
        kernels+="{\"suite\":\"${suite}\"},"
    fi

    for flavor in "${COMPATIBLE_FLAVORS[@]}"; do
        contains "${wanted_flavors}" "${flavor}" || continue
        images+="{\"board\":\"${board}\",\"suite\":\"${suite}\",\"flavor\":\"${flavor}\",\"version\":\"${RELASE_VERSION}\",\"kernel_type\":\"${KERNEL_TYPE}\"},"
    done
done

if [ -z "${images}" ]; then
    echo "Error: nothing to build for ${board} with suites \"${wanted_suites}\" and flavors \"${wanted_flavors}\"" >&2
    exit 1
fi

echo "images={\"include\":[${images%,}]}"
echo "kernels={\"include\":[${kernels%,}]}"
echo "has_kernels=$([ -n "${kernels}" ] && echo true || echo false)"
