#!/usr/bin/env bash
# End-to-end smoke test of the macOS install path of getcsound.sh.
#
# Runs on a real macOS CI runner and exercises the real code path: GitHub API
# run/artifact resolution, nightly.link download, ditto extraction, and a real
# `sudo installer` install of the .pkg (GitHub-hosted macOS runners allow
# passwordless sudo). It then verifies the installed csound binary works by
# rendering a small .csd to disk.
#
# The script requires an interactive terminal, so it is launched under `script`
# (which provides a pseudo-terminal).
#
# This depends on the csound/csound "develop" branch having a recent
# successful build with a macOS artifact.
#
# When RENDER_ARTIFACT_DIR is set, the rendered output, the .csd and the logs
# are copied there so CI can upload them for inspection.

cd "$(dirname "$0")/.." || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ARTIFACT_DIR="${RENDER_ARTIFACT_DIR:-}"
if [[ -n "$ARTIFACT_DIR" ]]; then
    mkdir -p "$ARTIFACT_DIR"
fi

save_artifact() { # src basename
    if [[ -n "$ARTIFACT_DIR" && -f "$1" ]]; then
        cp "$1" "$ARTIFACT_DIR/$2"
    fi
}

LOG="$WORK/install.log"
NORM="$WORK/install.norm.log"
: > "$NORM"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    printf '%s\n' '--- getcsound.sh output ---' >&2
    cat "$NORM" >&2
    exit 1
}

# Use /bin/bash (the macOS system bash, v3.2) to also cover version
# compatibility of getcsound.sh.
script "$LOG" /bin/bash ./getcsound.sh

# The transcript may use CRLF line endings (pseudo-terminal); normalize.
if [[ -f "$LOG" ]]; then
    tr -d '\r' < "$LOG" > "$NORM"
fi
save_artifact "$NORM" install.log

grep -q 'Using workflow run:' "$NORM" || fail "no workflow run was resolved"
grep -qE 'Using artifact: csound-7' "$NORM" || fail "no matching macOS artifact was resolved"
grep -qE '^Package: .*\.pkg' "$NORM" || fail "no .pkg was located"
grep -q 'Csound installed successfully.' "$NORM" || fail "install did not complete"

CSOUND_BIN="/Applications/Csound/csound"
if [[ ! -x "$CSOUND_BIN" ]]; then
    fail "csound binary not found at ${CSOUND_BIN}"
fi

if ! VERSION=$("$CSOUND_BIN" --version 2>&1); then
    printf '%s\n' "$VERSION" >&2
    fail "csound --version failed"
fi
printf 'csound --version: %s\n' "$VERSION"

# Render a trivial instrument to a WAV file on disk.
cat > "$WORK/render.csd" <<'CSD'
<CsoundSynthesizer>
<CsInstruments>
sr = 44100
kr = 4410
ksmps = 10
nchnls = 1

instr 1
  a1 oscili p4, p5
  outch 1, a1
endin

</CsInstruments>
<CsScore>
i 1 0 1 0.5 440
i 1 1 1 0.5 880
e
</CsScore>
</CsoundSynthesizer>
CSD
save_artifact "$WORK/render.csd" render.csd

(cd "$WORK" && "$CSOUND_BIN" -W -o out.wav render.csd) > "$WORK/render.log" 2>&1
rc=$?
save_artifact "$WORK/render.log" render.log
save_artifact "$WORK/out.wav" out.wav

if ((rc != 0)); then
    printf 'FAIL: csound render exited with %d\n' "$rc" >&2
    printf '%s\n' '--- render.log ---' >&2
    cat "$WORK/render.log" >&2
    exit 1
fi

if [[ ! -f "$WORK/out.wav" ]]; then
    printf 'FAIL: no output file written\n' >&2
    printf '%s\n' '--- render.log ---' >&2
    cat "$WORK/render.log" >&2
    exit 1
fi

SIZE=$(wc -c < "$WORK/out.wav")
if ((SIZE == 0)); then
    printf 'FAIL: rendered output is empty\n' >&2
    printf '%s\n' '--- render.log ---' >&2
    cat "$WORK/render.log" >&2
    exit 1
fi

# Report the file's MIME information for the maintainer.
MIME="unknown"
if file -b --mime-type "$WORK/out.wav" > "$WORK/mime.txt" 2>/dev/null; then
    MIME=$(cat "$WORK/mime.txt")
elif file -bI "$WORK/out.wav" > "$WORK/mime.txt" 2>/dev/null; then
    MIME=$(cat "$WORK/mime.txt")
fi
printf 'macOS install + render smoke test OK: %s (%d bytes, mime: %s)\n' "$WORK/out.wav" "$SIZE" "$MIME"
