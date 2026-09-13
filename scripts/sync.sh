#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBCSOUND_DATA="$HOME/dev/python/libcsound/libcsound/data"
SITE_DIR="$HOME/dev/forks/csound-plugins.github.io"

cp "$REPO_DIR/getcsound.sh"  "$LIBCSOUND_DATA"
cp "$REPO_DIR/getcsound.sh"  "$SITE_DIR/docs"

cp "$REPO_DIR/getcsound.ps1" "$LIBCSOUND_DATA"
cp "$REPO_DIR/getcsound.ps1" "$SITE_DIR/docs"

cd "$SITE_DIR"
mkdocs gh-deploy
git cm "update installers"
git push
