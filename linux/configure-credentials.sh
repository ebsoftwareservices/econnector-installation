#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

require_root

if [ ! -x "${INSTALL_HOME}/jdk/bin/java" ]; then
    echo "Econnector is not installed at ${INSTALL_HOME}." >&2
    exit 1
fi

if [ ! -f "${INSTALL_HOME}/econnector-daemon-keysafe.jar" ]; then
    echo "Missing keysafe jar at ${INSTALL_HOME}/econnector-daemon-keysafe.jar" >&2
    exit 1
fi

if [ -n "${EC_CLIENT_ID:-}" ] && [ -n "${EC_CLIENT_SECRET:-}" ]; then
    client_id=$EC_CLIENT_ID
    client_secret=$EC_CLIENT_SECRET
else
    printf "Client ID: "
    IFS= read -r client_id
    printf "Client Secret: "
    IFS= read -r client_secret
fi

if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
    echo "Client ID and Client Secret are required." >&2
    exit 1
fi

escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

client_id_escaped=$(escape_json "$client_id")
client_secret_escaped=$(escape_json "$client_secret")
json=$(printf '{"clientId":"%s","clientSecret":"%s"}' "$client_id_escaped" "$client_secret_escaped")
encrypted=$("${INSTALL_HOME}/jdk/bin/java" -jar "${INSTALL_HOME}/econnector-daemon-keysafe.jar" encrypt "$json")

printf '%s' "$encrypted" > "${INSTALL_HOME}/credentials.econnector"
chown econnector:econnector "${INSTALL_HOME}/credentials.econnector"
chmod 640 "${INSTALL_HOME}/credentials.econnector"

if [ -f "${INSTALL_HOME}/tokens.econnector" ]; then
    : > "${INSTALL_HOME}/tokens.econnector"
    chown econnector:econnector "${INSTALL_HOME}/tokens.econnector"
    chmod 640 "${INSTALL_HOME}/tokens.econnector"
fi

if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
    systemctl restart "${SERVICE_NAME}" || systemctl start "${SERVICE_NAME}"
elif [ "${EC_START_AFTER_CONFIGURE:-}" = "1" ]; then
    systemctl enable "${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"
fi

echo "Credentials saved."
