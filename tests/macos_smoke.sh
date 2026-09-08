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

cd "$(dirname "$0")/.." || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    printf '%s\n' '--- getcsound.sh output ---' >&2
    cat "$NORM" >&2
    exit 1
}

LOG="$WORK/install.log"
NORM="$WORK/install.norm.log"
: > "$NORM"

# Use /bin/bash (the macOS system bash, v3.2) to also cover version
# compatibility of getcsound.sh.
script "$LOG" /bin/bash ./getcsound.sh

# The transcript may use CRLF line endings (pseudo-terminal); normalize.
if [[ -f "$LOG" ]]; then
    tr -d '\r' < "$LOG" > "$NORM"
fi

grep -q 'Using workflow run:' "$NORM" || fail "no workflow run was resolved"
grep -qE 'Using artifact: csound-7' "$NORM" || fail "no matching macOS artifact was resolved"
grep -qE '^Package: .*\.pkg' "$NORM" || fail "no .pkg was located"
grep -q 'Csound installed successfully.' "$NORM" || fail "install did not complete"

CSOUND_BIN="/Applications/Csound/csound"
if [[ ! -x "$CSOUND_BIN" ]]; then
    fail "csound binary not found at ${CSOUND_BIN}"
fi

VERSION=$("$CSOUND_BIN" --version 2>&1) || fail "csound --version failed"
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
a1 oscil p4, p5, 1
out a1
endin
</CsInstruments>
<CsScore>
f 1 0 4096 10 1
i 1 0 1 0.5 440
e
</CsScore>
</CsoundSynthesizer>
CSD

(cd "$WORK" && "$CSOUND_BIN" -o out.wav render.csd) > "$WORK/render.log" 2>&1
rc=$?
if ((rc != 0)); then
    printf 'FAIL: csound render exited with %d\n' "$rc" >&2
    cat "$WORK/render.log" >&2
    exit 1
fi

if [[ ! -f "$WORK/out.wav" ]]; then
    printf 'FAIL: no output file written\n' >&2
    cat "$WORK/render.log" >&2
    exit 1
fi
if [[ "$(head -c 4 "$WORK/out.wav")" != "RIFF" ]]; then
    printf 'FAIL: output is not a WAV file\n' >&2
    ls -l "$WORK" >&2
    exit 1
fi

printf 'macOS install + render smoke test OK (rendered %d bytes)\n' "$(wc -c < "$WORK/out.wav")"
