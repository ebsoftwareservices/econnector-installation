#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

require_root

RELEASE_TAG=${1:-}
WORK_DIR=$(mktemp -d /tmp/econnector-upgrade.XXXXXX)
BACKUP_DIR="${WORK_DIR}/backup"
PKG_DIR="${WORK_DIR}/pkg"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "=== Econnector Upgrade ==="
if [ -n "$RELEASE_TAG" ]; then
    echo "Target version: ${RELEASE_TAG}"
else
    echo "Target version: latest"
fi

echo
echo "[1/4] Stopping econnector service..."
if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    systemctl stop "${SERVICE_NAME}"
fi

echo
echo "[2/4] Backing up credentials and removing existing installation..."
mkdir -p "$BACKUP_DIR"
if [ -f "${INSTALL_HOME}/credentials.econnector" ]; then
    cp "${INSTALL_HOME}/credentials.econnector" "${BACKUP_DIR}/credentials.econnector"
fi
if [ -f "${INSTALL_HOME}/tokens.econnector" ]; then
    cp "${INSTALL_HOME}/tokens.econnector" "${BACKUP_DIR}/tokens.econnector"
fi

if [ -d "${INSTALL_HOME}" ]; then
    sh "${SCRIPT_DIR}/uninstall.sh"
fi

echo
echo "[3/4] Downloading new release..."
mkdir -p "$PKG_DIR"

if [ -z "$RELEASE_TAG" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required to resolve the latest release tag." >&2
        exit 1
    fi
    RELEASE_TAG=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    if [ -z "$RELEASE_TAG" ]; then
        echo "Failed to query latest release tag." >&2
        exit 1
    fi
    echo "Resolved latest tag: ${RELEASE_TAG}"
fi

TAR_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/econnector-installation-linux.tar.gz"
TAR_PATH="${PKG_DIR}/econnector-installation-linux.tar.gz"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TAR_URL" -o "$TAR_PATH"
else
    wget -qO "$TAR_PATH" "$TAR_URL"
fi

mkdir -p "${PKG_DIR}/extracted"
tar -xzf "$TAR_PATH" -C "${PKG_DIR}/extracted"

echo
echo "[4/4] Installing new version..."
sh "${PKG_DIR}/extracted/install.sh"

if [ -f "${BACKUP_DIR}/credentials.econnector" ]; then
    cp "${BACKUP_DIR}/credentials.econnector" "${INSTALL_HOME}/credentials.econnector"
    chown econnector:econnector "${INSTALL_HOME}/credentials.econnector"
    chmod 640 "${INSTALL_HOME}/credentials.econnector"
fi
if [ -f "${BACKUP_DIR}/tokens.econnector" ]; then
    cp "${BACKUP_DIR}/tokens.econnector" "${INSTALL_HOME}/tokens.econnector"
    chown econnector:econnector "${INSTALL_HOME}/tokens.econnector"
    chmod 640 "${INSTALL_HOME}/tokens.econnector"
fi

if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    systemctl restart "${SERVICE_NAME}"
fi

echo
echo "Upgrade complete. Version ${RELEASE_TAG} installed."
