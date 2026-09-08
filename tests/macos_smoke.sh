#!/usr/bin/env bash
# End-to-end smoke test of the macOS install path of getcsound.sh.
#
# Runs on a real macOS CI runner and exercises the real code path: GitHub API
# run/artifact resolution, nightly.link download, and ditto extraction of the
# .pkg. sudo is shadowed with a no-op shim so nothing is installed on the
# runner. The script requires an interactive terminal, so it is launched under
# `script` (which provides a pseudo-terminal).
#
# This depends on the csound/csound "develop" branch having a recent
# successful build with a macOS artifact.

cd "$(dirname "$0")/.." || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

SUDO_LOG="$WORK/sudo.log"
export SUDO_LOG

cat > "$WORK/sudo" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${SUDO_LOG}"
exit 0
SH
chmod +x "$WORK/sudo"

# Make sure the shim really shadows /usr/bin/sudo, then run the script with
# the shim first on PATH.
PATH="$WORK:$PATH"
if [[ "$(command -v sudo)" != "$WORK/sudo" ]]; then
    printf 'FAIL: could not shadow sudo (found: %s)\n' "$(command -v sudo)" >&2
    exit 1
fi

LOG="$WORK/install.log"
# Use /bin/bash (the macOS system bash, v3.2) to also cover version
# compatibility of getcsound.sh.
script "$LOG" /bin/bash ./getcsound.sh

# The transcript may use CRLF line endings (pseudo-terminal); normalize.
NORM="$WORK/install.norm.log"
tr -d '\r' < "$LOG" > "$NORM"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    printf '%s\n' '--- getcsound.sh output ---' >&2
    cat "$NORM" >&2
    printf '%s\n' '--- sudo.log ---' >&2
    if [[ -f "$SUDO_LOG" ]]; then
        cat "$SUDO_LOG" >&2
    else
        printf '%s\n' '(empty: sudo was never invoked)' >&2
    fi
    exit 1
}

grep -q 'Using workflow run:' "$NORM" || fail "no workflow run was resolved"
grep -qE 'Using artifact: csound-7' "$NORM" || fail "no matching macOS artifact was resolved"
grep -qE '^Package: .*\.pkg' "$NORM" || fail "no .pkg was located"
grep -q 'Csound installed successfully.' "$NORM" || fail "install did not complete"
[[ -s "$SUDO_LOG" ]] || fail "sudo installer was never invoked"
grep -qE 'installer -pkg .*\.pkg -target /' "$SUDO_LOG" || fail "unexpected sudo invocation: $(cat "$SUDO_LOG")"

printf 'macOS smoke test OK\n'
