# econnector-installation

Developer repo for packaging Econnector installers. End-user instructions live in `windows/install-instructions.txt` and `linux/install-instructions.txt`.

## Repository layout

```
econnector-installation/
├── windows/                 # Windows installer source → econnector-installation.zip
│   ├── install.bat
│   ├── uninstall.bat
│   ├── upgrade.bat
│   ├── install-instructions.txt
│   └── files/               # Static + CI-staged release artifacts
│       ├── prunsrv.exe      # Apache Procrun (committed manually)
│       └── …                # econnector-daemon.jar, application.json, econnector-ui.exe (from CI)
├── linux/                   # Linux installer source → econnector-installation-linux.tar.gz
│   ├── install.sh
│   ├── configure-credentials.sh
│   ├── uninstall.sh
│   ├── upgrade.sh
│   ├── common.sh
│   ├── econnector.service
│   ├── install-instructions.txt
│   ├── bin/                 # jsvc-amd64, jsvc-arm64 (built in CI)
│   └── files/               # econnector-daemon.jar, keysafe jar, application.json (from CI)
└── vagrant/                 # Local Linux install tests (see vagrant/README.md)
```

Windows and Linux release packages are built from their respective directories. The extracted zip/tar contents are what users run on the target machine (scripts at the package root).

## Prerequisites before release

Publish dependent repos first (workflow uses `latest`):

1. [econnector-daemon](https://github.com/ebsoftwareservices/econnector-daemon) → `econnector-daemon.zip`
2. [econnector-daemon-keysafe](https://github.com/ebsoftwareservices/econnector-daemon-keysafe) → `econnector-daemon-keysafe.zip` (Linux only)
3. [econnector-ui](https://github.com/ebsoftwareservices/econnector-ui) → `econnector-ui.zip` (Windows only)

Ensure `windows/files/` contains static Windows-only binaries such as `prunsrv.exe` before releasing.

## Release workflow

Run **Release the application** (`.github/workflows/release.yml`) with a release tag.

The `release` job runs at the **repository root** (`$GITHUB_WORKSPACE` after checkout):

| Step | Working directory | What it does |
|------|-------------------|--------------|
| Checkout | repo root | Provides `linux/*.sh`, `windows/*.bat` |
| Download jsvc artifacts | `linux/bin/` | amd64 + arm64 jsvc from matrix job |
| Download daemon/keysafe | `linux/files/` | Linux payloads |
| Download daemon/UI | `windows/files/` | Windows payloads |
| **Build Linux Tarball** | repo root | `tar -czf … -C linux .` |
| **Build Windows Zip** | repo root | `(cd windows && zip -r ../econnector-installation.zip .)` |

Outputs:

- `econnector-installation.zip` — Windows
- `econnector-installation-linux.tar.gz` — Linux

### jsvc build job

Separate matrix job (`ubuntu-latest` + `ubuntu-24.04-arm`) compiles jsvc and uploads artifacts; the release job merges them into `linux/bin/`.

## Windows packaging notes

- `install.bat` copies `windows/files/*` to `C:\econnector` and registers the Procrun service.
- JDK is downloaded at install time (Corretto 25 x64); not bundled in the zip.
- Do not use spaces or special characters in `SERVICE_NAME` (used as directory name; Procrun limitation).

## Linux packaging notes

One-line install (latest release):

```shell
curl -fsSL https://raw.githubusercontent.com/ebsoftwareservices/econnector-installation/refs/heads/main/linux/install-from-release.sh | sudo bash
```

See [`linux/install-instructions.txt`](linux/install-instructions.txt) for tagged installs and manual steps.

- `install.sh` picks `bin/jsvc-$ARCH`, downloads Corretto 25 for the guest architecture, and installs systemd unit to `/opt/econnector`.
- `configure-credentials.sh` encrypts Client ID / Secret via `econnector-daemon-keysafe.jar`.
- Supports **amd64** and **arm64**.

## Local Linux testing

See [`vagrant/README.md`](vagrant/README.md). Quick start:

```shell
cd vagrant
./prepare-local-package.sh
vagrant up ubuntu24
```
