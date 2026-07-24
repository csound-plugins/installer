# Csound 7 Installer

A small bootstrapping script that downloads the Csound 7 portable 
release from the [csound-plugins/csound-plugins](https://github.com/csound-plugins/csound-plugins)
GitHub repository, verifies its integrity, and runs the bundled installer.

## Quick install 

### Linux / macOS

```bash
curl -fsSL https://csound-plugins.github.io/installer/install.sh | bash
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

## Requirements

### Linux / macOS

- `curl`
- `unzip`
- `mktemp`
- `sha256sum` or `shasum`

