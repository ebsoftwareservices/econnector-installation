#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

require_root

echo "Uninstalling Econnector..."

# Leave INSTALL_HOME before deleting it. If this script is the installed copy
# under /opt/econnector, rename the directory first so the running script is not
# removed out from under a POSIX sh that reads the file incrementally.
cd /

if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    systemctl stop "${SERVICE_NAME}"
fi

if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
    systemctl disable "${SERVICE_NAME}"
fi

if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
fi

if [ -d "${INSTALL_HOME}" ]; then
    doomed="${INSTALL_HOME}.removing.$$"
    mv "${INSTALL_HOME}" "$doomed"
    rm -rf "$doomed"
fi

if [ -e "${INSTALL_HOME}" ]; then
    echo "ERROR: Failed to remove ${INSTALL_HOME}." >&2
    exit 1
fi

echo "Econnector uninstalled."
