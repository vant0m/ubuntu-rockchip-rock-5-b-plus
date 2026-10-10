#!/bin/bash

# Download the newest version of a package from the Ubuntu archive, checked
# against the signed InRelease files of the release and its -updates pocket.
#
# Usage: download-from-archive.sh SUITE INDEX PACKAGE [OUTDIR]
#   INDEX is the index the package is listed in, relative to the component
#   directory, for example "main/source/Sources" for a source package or
#   "universe/binary-amd64/Packages" for a binary package.
#
# Source packages must be native (a single .tar.xz), the downloaded file
# path is printed on stdout.

set -eE
trap 'echo Error: in $0 on line $LINENO >&2' ERR

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 SUITE INDEX PACKAGE [OUTDIR]" >&2
    exit 1
fi

suite="$1"
index="$2"
package="$3"
outdir="${4:-.}"

case "${index}" in
    *binary-amd64*|*binary-i386*|*/source/*) mirror="http://archive.ubuntu.com/ubuntu" ;;
    *) mirror="http://ports.ubuntu.com/ubuntu-ports" ;;
esac
keyring="/usr/share/keyrings/ubuntu-archive-keyring.gpg"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

# Check a file against its SHA512 or, for older releases, SHA256 checksum
check_file() {
    local file="$1"
    local sha512="$2"
    local sha256="$3"

    if [ -n "${sha512}" ]; then
        echo "${sha512}  ${file}" | sha512sum --check --quiet
    elif [ -n "${sha256}" ]; then
        echo "${sha256}  ${file}" | sha256sum --check --quiet
    else
        echo "Error: no checksum found for $(basename "${file}")" >&2
        exit 1
    fi
}

best_version=""
best_paragraph=""
for pocket in "${suite}" "${suite}-updates"; do
    # The -updates pocket does not exist for a release in development
    curl -fsSL -o "${tmp_dir}/InRelease" "${mirror}/dists/${pocket}/InRelease" || continue
    if ! gpgv --keyring "${keyring}" --output "${tmp_dir}/Release" "${tmp_dir}/InRelease" 2> "${tmp_dir}/gpgv.log"; then
        cat "${tmp_dir}/gpgv.log" >&2
        echo "Error: bad signature on ${mirror}/dists/${pocket}/InRelease" >&2
        exit 1
    fi

    curl -fsSL -o "${tmp_dir}/index.xz" "${mirror}/dists/${pocket}/${index}.xz"
    check_file "${tmp_dir}/index.xz" "$(awk -v f="${index}.xz" '/^SHA512:/ { x = 1; next } /^[^ ]/ { x = 0 } x && $3 == f { print $1 }' "${tmp_dir}/Release")" \
        "$(awk -v f="${index}.xz" '/^SHA256:/ { x = 1; next } /^[^ ]/ { x = 0 } x && $3 == f { print $1 }' "${tmp_dir}/Release")"

    paragraph="$(xz -dc "${tmp_dir}/index.xz" | awk -v RS= -v p="${package}" '$0 ~ "(^|\n)Package: " p "\n" { print; exit }')"
    version="$(echo "${paragraph}" | awk '/^Version:/ { print $2 }')"
    if [ -n "${version}" ] && { [ -z "${best_version}" ] || dpkg --compare-versions "${version}" gt "${best_version}"; }; then
        best_version="${version}"
        best_paragraph="${paragraph}"
    fi
done

if [ -z "${best_version}" ]; then
    echo "Error: could not find ${package} in ${index} for ${suite}" >&2
    exit 1
fi

if [[ ${index} == */source/* ]]; then
    directory="$(echo "${best_paragraph}" | awk '/^Directory:/ { print $2 }')"
    file="$(echo "${best_paragraph}" | awk '/^Files:/ { x = 1; next } /^[^ ]/ { x = 0 } x && $3 ~ /\.tar\.xz$/ { print $3; exit }')"
    sha512="$(echo "${best_paragraph}" | awk -v f="${file}" '/^Checksums-Sha512:/ { x = 1; next } /^[^ ]/ { x = 0 } x && $3 == f { print $1 }')"
    sha256="$(echo "${best_paragraph}" | awk -v f="${file}" '/^Checksums-Sha256:/ { x = 1; next } /^[^ ]/ { x = 0 } x && $3 == f { print $1 }')"
    path="${directory}/${file}"
else
    path="$(echo "${best_paragraph}" | awk '/^Filename:/ { print $2 }')"
    file="$(basename "${path}")"
    sha512="$(echo "${best_paragraph}" | awk '/^SHA512:/ { print $2 }')"
    sha256="$(echo "${best_paragraph}" | awk '/^SHA256:/ { print $2 }')"
fi

echo "Downloading ${package} ${best_version} from ${suite}" >&2
mkdir -p "${outdir}"
curl -fsSL -o "${tmp_dir}/${file}" "${mirror}/${path}"
check_file "${tmp_dir}/${file}" "${sha512}" "${sha256}"
mv "${tmp_dir}/${file}" "${outdir}/${file}"

echo "${outdir}/${file}"
