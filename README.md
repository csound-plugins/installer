# Csound 7 Installer

A small bootstrapping script that downloads the Csound 7 release for the
current platform and installs it:

- On **Linux** it downloads the portable release from the
  [csound-plugins/csound-plugins](https://github.com/csound-plugins/csound-plugins)
  GitHub repository, verifies its SHA-256 checksum, and runs the bundled installer.
- On **macOS** it downloads the official `.pkg` installer built by the
  `csound_builds` workflow of the [csound/csound](https://github.com/csound/csound)
  repository (branch `develop`, which corresponds to Csound 7) and installs it
  with the system `installer`.
- On **Windows** (x86_64 only) it downloads the official `.exe` installer built
  by the same `csound_builds` workflow and runs it. Windows on ARM64 is not
  supported yet.

The shell script is uploaded to the csound-plugins site as
`csound-plugins.github.io/getcsound.sh`; the PowerShell script as
`csound-plugins.github.io/getcsound.ps1`.

## Quick install 

### Linux

```bash
curl -fsSL https://csound-plugins.github.io/getcsound.sh | bash
```

### macOS

The `.pkg` is installed with `sudo`, so you must run this from a terminal:

```bash
curl -fsSL https://csound-plugins.github.io/getcsound.sh | bash
```

The installer detects the os and architecture and downloads the corresponding distribution
and prints the exact archive URL before downloading it.

To show the checksum-file URL and the expected and calculated SHA-256 checksums:

```bash
curl -fsSL https://csound-plugins.github.io/getcsound.sh | bash -s -- --verbose
```

`--verbose` belongs to the bootstrap script. To pass a `--verbose` flag to the
bundled installer instead, separate it with `--`:

```bash
bash ./install-csound7-linux.sh -- --verbose
```

Use `--help` to display bootstrap options without downloading anything. Use
`--help-all` to download and verify the release, then display both bootstrap
options and the bundled installer's supported options and parameters:

```bash
curl -fsSL https://csound-plugins.github.io/installer/install.sh | bash -s -- --help-all
```

### Windows

Windows on ARM64 is not supported yet; the installer exits with an error there.

The `.exe` is a machine-wide Inno Setup installer, so it needs Administrator
rights. Run this from a PowerShell session (a UAC prompt will appear unless the
session is already elevated):

```powershell
irm https://csound-plugins.github.io/getcsound.ps1 | iex
```

To show the download URLs and other diagnostics:

```powershell
& ([scriptblock]::Create((irm https://csound-plugins.github.io/getcsound.ps1))) --verbose
```

`--verbose` belongs to the bootstrap script. To pass extra flags to the Inno
Setup installer instead, separate them with `--`:

```powershell
& ([scriptblock]::Create((irm https://csound-plugins.github.io/getcsound.ps1))) -- /SILENT
```

### Choosing what to install

Use `--help` to display bootstrap options without downloading anything, and
`--help-all` to also show information about the bundled installer.

By default macOS and Windows install the latest successful `csound_builds`
workflow artifact. Pass `--release` to install the installer published with the
latest GitHub release instead:

```bash
curl -fsSL https://csound-plugins.github.io/getcsound.sh | bash -s -- --release
```

```powershell
& ([scriptblock]::Create((irm https://csound-plugins.github.io/getcsound.ps1))) --release
```

Linux always installs from the latest build, so `--release` has no effect there. Set
`CSOUND7_RELEASE_TAG` to pin a specific release tag instead of `latest`.

## What the script does

### Linux

1. Detects the operating system and CPU architecture.
2. Downloads the release asset.
3. Downloads the matching SHA-256 checksum file.
4. Verifies the archive's checksum before extracting it.
5. Locates the bundled `install.sh` inside the archive and runs it.

### macOS

1. Looks up the latest successful `csound_builds` workflow run of
   `csound/csound` on the `develop` branch.
2. Selects the artifact matching `csound-7.*-macos*`.
3. Downloads it through the anonymous [nightly.link](https://nightly.link)
   mirror (GitHub Actions artifacts require authentication otherwise).
4. Extracts the `.pkg` and installs it with `sudo installer -pkg ... -target /`.

With `--release`, steps 1-3 are replaced by downloading
`csound-macos-<tag>.zip` from the latest `csound/csound` release.

Because the macOS install runs under `sudo`, it requires an interactive
terminal session.

### Windows

1. Detects the CPU architecture and refuses to install on ARM64.
2. Looks up the latest successful `csound_builds` workflow run of
   `csound/csound` on the `develop` branch.
3. Selects the artifact matching `Csound_x64-*-windows-installer`.
4. Downloads it through the anonymous [nightly.link](https://nightly.link)
   mirror (GitHub Actions artifacts require authentication otherwise).
5. Extracts the `.exe` and runs it elevated, silently, adding Csound to `PATH`.

With `--release`, steps 2-4 are replaced by downloading
`csound-windows-<tag>.zip` from the latest `csound/csound` release.

## Environment variables

| Variable                  | Default                        | Description                                   |
|---------------------------|--------------------------------|-----------------------------------------------|
| `CSOUND7_TAG`             | `latest`                       | GitHub release tag to install (Linux).        |
| `CSOUND7_ASSET`           | Depends on platform            | Name of the release asset to download (Linux).|
| `CSOUND7_REPO`            | Depends on platform            | `owner/repo` providing the installer: `csound-plugins/csound-plugins` on Linux, `csound/csound` on macOS and Windows. |
| `CSOUND7_WORKFLOW`        | `csound_builds.yml`            | Workflow whose artifacts are used (macOS, Windows). |
| `CSOUND7_MACOS_BRANCH`    | `develop`                      | Branch of the workflow runs to use (macOS).   |
| `CSOUND7_MACOS_ASSET`     | `csound-7.*-macos*`            | Glob of the artifact name to install (macOS). |
| `CSOUND7_MACOS_RUN_ID`    | *(latest successful run)*      | Pin a specific workflow run (macOS).          |
| `CSOUND7_MACOS_ARTIFACT`  | *(first match of the glob)*    | Pin a specific artifact name (macOS).         |
| `CSOUND7_WINDOWS_BRANCH`  | `develop`                      | Branch of the workflow runs to use (Windows). |
| `CSOUND7_WINDOWS_ASSET`   | `Csound_x64-*-windows-installer` | Glob of the artifact name to install (Windows). |
| `CSOUND7_WINDOWS_RUN_ID`  | *(latest successful run)*      | Pin a specific workflow run (Windows).        |
| `CSOUND7_WINDOWS_ARTIFACT`| *(first match of the glob)*    | Pin a specific artifact name (Windows).       |
| `CSOUND7_WINDOWS_EXE`     | `Csound7-windows_x86_64-*.exe` | Glob of the installer executable (Windows).   |
| `CSOUND7_RELEASE_TAG`     | `latest`                       | Release tag installed with `--release` (macOS, Windows); `latest` uses the newest release. |
| `CSOUND7_GH_TOKEN`        | *(anonymous)*                  | GitHub token used to authenticate the API queries when set (also honors `GH_TOKEN` / `GITHUB_TOKEN`). Recommended on CI, where anonymous API calls are rate-limited. |

## Options

Both the shell and the PowerShell scripts accept the same options.

| Option | Description |
|--------|-------------|
| `--help` | Show bootstrap options without downloading the installer. |
| `--help-all` | Show bootstrap options plus information about the bundled installer (on Linux, download and verify it first, then show its help). |
| `--release` | Install the latest GitHub release instead of the latest successful `csound_builds` workflow run (macOS and Windows; no effect on Linux). |
| `--verbose` | Print the download URLs and other diagnostic information (checksums on Linux). |

## Requirements

### Linux

- `curl`
- `unzip`
- `mktemp`
- `sha256sum` or `shasum`

### macOS

Only tools that ship with macOS are used (`curl`, `mktemp`, `ditto`,
`installer`), plus `sudo`. An interactive terminal session is required.

### Windows

- Windows PowerShell 5.1 or later (works with PowerShell 7 as well).
- Administrator rights, since the installer writes to `%ProgramFiles%` and
  machine-wide environment variables. A UAC prompt is shown when needed.
