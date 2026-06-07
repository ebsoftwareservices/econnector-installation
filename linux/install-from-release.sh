#!/bin/sh
# Download a GitHub release tarball and run install.sh.
# Usage:
#   sudo ./install-from-release.sh           # latest release
#   sudo ./install-from-release.sh v1.2.3    # specific tag
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/ebsoftwareservices/econnector-installation/refs/heads/main/linux/install-from-release.sh | sudo bash
#   curl -fsSL https://raw.githubusercontent.com/ebsoftwareservices/econnector-installation/refs/heads/main/linux/install-from-release.sh | sudo bash -s -- v1.2.3

set -eu

GITHUB_REPO=ebsoftwareservices/econnector-installation
ASSET_NAME=econnector-installation-linux.tar.gz

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

require_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required." >&2
        exit 1
    fi
}

resolve_release_tag() {
    tag=${1:-}
    if [ -n "$tag" ]; then
        printf '%s\n' "$tag"
        return
    fi

    resolved=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -1)
    if [ -z "$resolved" ]; then
        echo "Failed to resolve latest release tag from GitHub." >&2
        exit 1
    fi
    printf '%s\n' "$resolved"
}

main() {
    require_root
    require_curl

    release_tag=$(resolve_release_tag "${1:-}")
    echo "Installing Econnector release ${release_tag}..."

    work_dir=$(mktemp -d /tmp/econnector-install.XXXXXX)
    pkg_dir="${work_dir}/pkg"
    tar_path="${work_dir}/${ASSET_NAME}"
    trap 'rm -rf "$work_dir"' EXIT

    tar_url="https://github.com/${GITHUB_REPO}/releases/download/${release_tag}/${ASSET_NAME}"
    echo "Downloading ${tar_url}..."
    curl -fsSL "$tar_url" -o "$tar_path"

    mkdir -p "$pkg_dir"
    tar -xzf "$tar_path" -C "$pkg_dir"

    if [ ! -x "${pkg_dir}/install.sh" ]; then
        echo "Downloaded package is missing install.sh." >&2
        exit 1
    fi

    sh "${pkg_dir}/install.sh"

    echo
    echo "Installation complete (${release_tag})."
    echo "Next step: configure credentials with"
    echo "  sudo /opt/econnector/configure-credentials.sh"
}

main "$@"
