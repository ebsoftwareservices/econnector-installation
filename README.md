# Econnector installation

This repo is used for econnector installation.

## Windows

Put all the needed files as the structure you want to keep on user's laptop in `files` dir. The install script will copy them to `C:\econnector`.

Modify `install.bat` and `uninstall.bat` to update the installation config. Do not put special characters or spaces in `SERVICE_NAME`; it is used as a directory name and Apache Commons Daemon has issues reading such paths.

The install script also manages JVM installation, so Java does not need to be pre-installed on the system.

## Linux

Supports **amd64** and **arm64** on systemd-based distros (yum/dnf and apt families).

### Prerequisites

- root/sudo access
- systemd
- curl or wget
- Supported architecture: x86_64 (amd64) or aarch64 (arm64)

### Install

Extract `econnector-installation-linux.tar.gz`, then run:

```shell
cd econnector-installation-linux
sudo ./install.sh
sudo ./configure-credentials.sh
```

`install.sh` downloads Amazon Corretto 25, installs the daemon under `/opt/econnector`, and starts the systemd service.

`configure-credentials.sh` prompts for Client ID and Client Secret, encrypts them with `econnector-daemon-keysafe.jar`, and writes `/opt/econnector/credentials.econnector`.

### Service management

```shell
systemctl status econnector
systemctl restart econnector
```

Logs: `/opt/econnector/econnector-daemon-logs/`

### Upgrade

```shell
sudo ./upgrade.sh          # latest release
sudo ./upgrade.sh v1.2.3     # specific tag
```

### Uninstall

```shell
sudo ./uninstall.sh
```

See [`linux/install-instructions.txt`](linux/install-instructions.txt) for more details.

## Release order

Before the first Linux installation release, publish:

1. `econnector-daemon` release (`econnector-daemon.zip`)
2. `econnector-daemon-keysafe` release (`econnector-daemon-keysafe.zip`)
3. `econnector-installation` release (Windows zip + Linux tar.gz)

## Local Linux testing (Vagrant)

Use Vagrant to run full systemd install tests on real Linux VMs (apt and yum/dnf).

### Prerequisites

- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.oracle.com/virtualization/technologies/vm/downloads/virtualbox-downloads.html) **7.2+** (Apple Silicon: choose the Apple Silicon host package)
- Sibling repos checked out: `econnector-daemon`, `econnector-daemon-keysafe`

See [`vagrant/README.md`](vagrant/README.md) for setup notes. No extra Vagrant plugin is required.

### Run

```shell
cd vagrant
./prepare-local-package.sh   # builds jars into ../linux/files
vagrant up ubuntu24           # apt-based (Ubuntu 24.04)
vagrant up rocky9             # dnf-based (Rocky 9)
vagrant ssh ubuntu24 -c 'systemctl status econnector'
vagrant destroy -f
```

The guest provisioner will:

1. Compile `jsvc` for the VM architecture (if not already present)
2. Run `install.sh` and `configure-credentials.sh`
3. Verify `systemctl status econnector`

On Apple Silicon Macs, VMs run **arm64** natively. On Intel Macs, VMs run **amd64** natively.

For automated credential setup (Vagrant/CI), set:

```shell
export EC_CLIENT_ID=...
export EC_CLIENT_SECRET=...
sudo ./configure-credentials.sh
```
