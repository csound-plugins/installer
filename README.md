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

The script is uploaded to the csound-plugins site as `csound-plugins.github.io/getcsound.sh`

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

Windows is not supported at the moment

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

Because the macOS install runs under `sudo`, it requires an interactive
terminal session.


## Environment variables

| Variable                  | Default                        | Description                                   |
|---------------------------|--------------------------------|-----------------------------------------------|
| `CSOUND7_TAG`             | `latest`                       | GitHub release tag to install (Linux).        |
| `CSOUND7_ASSET`           | Depends on platform            | Name of the release asset to download (Linux).|
| `CSOUND7_REPO`            | Depends on platform            | `owner/repo` providing the installer: `csound-plugins/csound-plugins` on Linux, `csound/csound` on macOS. |
| `CSOUND7_WORKFLOW`        | `csound_builds.yml`            | Workflow whose artifacts are used (macOS).    |
| `CSOUND7_MACOS_BRANCH`    | `develop`                      | Branch of the workflow runs to use (macOS).   |
| `CSOUND7_MACOS_ASSET`     | `csound-7.*-macos*`            | Glob of the artifact name to install (macOS). |
| `CSOUND7_MACOS_RUN_ID`    | *(latest successful run)*      | Pin a specific workflow run (macOS).          |
| `CSOUND7_MACOS_ARTIFACT`  | *(first match of the glob)*    | Pin a specific artifact name (macOS).         |
| `CSOUND7_GH_TOKEN`        | *(anonymous)*                  | GitHub token used to authenticate the API queries when set (also honors `GH_TOKEN` / `GITHUB_TOKEN`). Recommended on CI, where anonymous API calls are rate-limited. |

## Options

| Option | Description |
|--------|-------------|
| `--help` | Show bootstrap options without downloading the installer. |
| `--help-all` | Download and verify the installer, then show bootstrap and bundled installer help (Linux only). |
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
