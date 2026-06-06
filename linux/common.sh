#!/bin/sh

SERVICE_NAME=econnector
INSTALL_HOME=/opt/econnector
CORRETTO_VERSION=25.0.2.10.1
DAEMON_CLASS=com.ebsoftwareservices.econnector.daemon.EconnectorDaemonOnLinux
GITHUB_REPO=ebsoftwareservices/econnector-installation

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo amd64 ;;
        aarch64|arm64) echo arm64 ;;
        *)
            echo "Unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

corretto_download_url() {
    arch=$1
    case "$arch" in
        amd64)
            echo "https://corretto.aws/downloads/resources/${CORRETTO_VERSION}/amazon-corretto-${CORRETTO_VERSION}-linux-x64.tar.gz"
            ;;
        arm64)
            echo "https://corretto.aws/downloads/resources/${CORRETTO_VERSION}/amazon-corretto-${CORRETTO_VERSION}-linux-aarch64.tar.gz"
            ;;
        *)
            echo "Unsupported architecture for Corretto: $arch" >&2
            exit 1
            ;;
    esac
}

install_corretto() {
    arch=$1
    jdk_tar="${INSTALL_HOME}/jdk.tar.gz"
    url=$(corretto_download_url "$arch")

    echo "Downloading Amazon Corretto ${CORRETTO_VERSION} for ${arch}..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$jdk_tar"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$jdk_tar" "$url"
    else
        echo "curl or wget is required to download the JDK." >&2
        exit 1
    fi

    tar -xzf "$jdk_tar" -C "$INSTALL_HOME"
    rm -f "$jdk_tar"

    extracted_jdk=$(find "$INSTALL_HOME" -maxdepth 1 -type d -name 'amazon-corretto-*' | head -1)
    if [ -z "$extracted_jdk" ]; then
        echo "Failed to locate extracted JDK directory under ${INSTALL_HOME}." >&2
        exit 1
    fi

    mv "$extracted_jdk" "${INSTALL_HOME}/jdk"
}

ensure_econnector_user() {
    if ! id econnector >/dev/null 2>&1; then
        useradd --system --no-create-home --shell /usr/sbin/nologin econnector
    fi
}

init_credential_files() {
    touch "${INSTALL_HOME}/credentials.econnector"
    touch "${INSTALL_HOME}/tokens.econnector"
    chown econnector:econnector "${INSTALL_HOME}/credentials.econnector" "${INSTALL_HOME}/tokens.econnector"
    chmod 640 "${INSTALL_HOME}/credentials.econnector" "${INSTALL_HOME}/tokens.econnector"
}

install_systemd_unit() {
    script_dir=$1
    unit_path="/etc/systemd/system/${SERVICE_NAME}.service"
    cp "${script_dir}/econnector.service" "$unit_path"
    systemctl daemon-reload
}
