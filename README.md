# Csound 7 Installer

A small bootstrapping script that downloads the Csound 7 portable 
release from the [csound-plugins/csound-plugins](https://github.com/csound-plugins/csound-plugins)
GitHub repository, verifies its integrity, and runs the bundled installer.

## Quick install 

### Linux / macOS

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

1. Detects the operating system.
2. Downloads the release asset.
3. Downloads the matching SHA-256 checksum file.
4. Verifies the archive's checksum before extracting it.
5. Locates the bundled `install.sh` inside the archive and runs it.


## Environment variables

| Variable          | Default                     | Description                              |
|-------------------|-----------------------------|------------------------------------------|
| `CSOUND7_TAG`     | `latest`                    | GitHub release tag to install.           |
| `CSOUND7_ASSET`   | Depends on platform         | Name of the release asset to download.   |

## Options

| Option | Description |
|--------|-------------|
| `--help` | Show bootstrap options without downloading the installer. |
| `--help-all` | Download and verify the installer, then show bootstrap and bundled installer help. |
| `--verbose` | Print the checksum-file URL plus expected and calculated SHA-256 checksums. |

## Requirements

### Linux / macOS

- `curl`
- `unzip`
- `mktemp`
- `sha256sum` or `shasum`
