# Agent notes

## This repo is the source of truth for the Csound installers

`getcsound.sh` and `getcsound.ps1` here are the canonical scripts. Every other
copy is a generated mirror and must be kept byte-identical to these files:

- `~/dev/python/libcsound/libcsound/data/getcsound.sh`
- `~/dev/python/libcsound/libcsound/data/getcsound.ps1`
- `~/dev/forks/csound-plugins.github.io/docs/` (published site)

**Edit the scripts here, never in the mirrors.** `scripts/sync.sh` copies both
files to the mirrors and then deploys/pushes the site (`mkdocs gh-deploy` +
`git push`), so run it only when a deploy is actually intended; otherwise just
copy the two files to the libcsound `data/` directory.

`libcsound` itself (the Python package) must know nothing about GitHub tokens
or CI. All installer/token/CI logic lives in these scripts.

## Authentication

The scripts resolve a GitHub API token from `CSOUND7_GH_TOKEN`, `GH_TOKEN` or
`GITHUB_TOKEN`, and fall back to `gh auth token`. CI passes the workflow token
via `GH_TOKEN` (see `.github/workflows/ci.yml`). Anonymous GitHub API requests
are rate-limited and commonly fail with HTTP 403 from shared runner IPs.

## Tests

Run `bash tests/lint.sh` (syntax, CLI smoke tests, token-auth regression tests).
