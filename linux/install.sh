#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

require_root

ARCH=$(detect_arch)
echo "Installing Econnector for ${ARCH}..."

if [ -d "${INSTALL_HOME}" ]; then
    if [ -f "${INSTALL_HOME}/jsvc" ] || systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        echo "Econnector appears to be already installed. Run uninstall.sh first." >&2
        exit 1
    fi
fi

mkdir -p "${INSTALL_HOME}/econnector-daemon-logs"

if [ ! -f "${SCRIPT_DIR}/bin/jsvc-${ARCH}" ]; then
    echo "Missing jsvc binary for ${ARCH}: ${SCRIPT_DIR}/bin/jsvc-${ARCH}" >&2
    exit 1
fi

cp "${SCRIPT_DIR}/bin/jsvc-${ARCH}" "${INSTALL_HOME}/jsvc"
chmod 755 "${INSTALL_HOME}/jsvc"

for file in econnector-daemon.jar econnector-daemon-keysafe.jar application.json; do
    if [ ! -f "${SCRIPT_DIR}/files/${file}" ]; then
        echo "Missing required file: ${SCRIPT_DIR}/files/${file}" >&2
        exit 1
    fi
    cp "${SCRIPT_DIR}/files/${file}" "${INSTALL_HOME}/"
done

cp "${SCRIPT_DIR}/configure-credentials.sh" "${INSTALL_HOME}/"
cp "${SCRIPT_DIR}/uninstall.sh" "${INSTALL_HOME}/"
cp "${SCRIPT_DIR}/upgrade.sh" "${INSTALL_HOME}/"
cp "${SCRIPT_DIR}/common.sh" "${INSTALL_HOME}/"
chmod 755 "${INSTALL_HOME}/configure-credentials.sh" "${INSTALL_HOME}/uninstall.sh" "${INSTALL_HOME}/upgrade.sh"

install_corretto "$ARCH"
ensure_econnector_user
init_credential_files

chown -R econnector:econnector "${INSTALL_HOME}/econnector-daemon-logs"
chown econnector:econnector "${INSTALL_HOME}/econnector-daemon.jar" "${INSTALL_HOME}/application.json"
chmod 755 "${INSTALL_HOME}/jsvc"
chmod 644 "${INSTALL_HOME}/econnector-daemon.jar" "${INSTALL_HOME}/application.json"
chmod 644 "${INSTALL_HOME}/econnector-daemon-keysafe.jar"

install_systemd_unit "$SCRIPT_DIR"

if [ "${EC_SKIP_AUTOSTART:-}" != "1" ]; then
    systemctl enable "${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"
fi

echo
echo "Econnector installed to ${INSTALL_HOME}."
echo "Next step: configure credentials with"
echo "  sudo ${INSTALL_HOME}/configure-credentials.sh"
echo
echo "Upgrade or uninstall later with:"
echo "  sudo ${INSTALL_HOME}/upgrade.sh"
echo "  sudo ${INSTALL_HOME}/uninstall.sh"
echo
echo "Check service status with:"
echo "  systemctl status ${SERVICE_NAME}"
