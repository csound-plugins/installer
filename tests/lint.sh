#!/usr/bin/env bash
# Static checks and CLI smoke tests for getcsound.sh.
# Designed to run on a Linux CI runner (no installs are performed).

cd "$(dirname "$0")/.." || exit 1

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# write_uname OS -> prints a directory holding a fake uname reporting OS
write_uname() {
    local dir="$WORK/uname-$RANDOM"
    mkdir -p "$dir"
    printf '#!/usr/bin/env bash\necho %s\n' "$1" > "$dir/uname"
    chmod +x "$dir/uname"
    printf '%s\n' "$dir"
}

echo "== syntax (bash -n) =="
bash -n getcsound.sh || fail "getcsound.sh has a syntax error"
for f in tests/*.sh; do
    bash -n "$f" || fail "$f has a syntax error"
done

if command -v shellcheck >/dev/null 2>&1; then
    echo "== shellcheck =="
    shellcheck getcsound.sh tests/*.sh || fail "shellcheck reported issues"
else
    echo "== shellcheck skipped (not installed) =="
fi

echo "== --help =="
out=$(bash getcsound.sh --help 2>&1)
rc=$?
[[ $rc -eq 0 ]] || fail "--help exited with $rc"
grep -q 'Usage:' <<<"$out" || fail "--help does not print usage"

echo "== macOS --help-all exits without downloading =="
dir=$(write_uname Darwin)
out=$(PATH="$dir:$PATH" bash getcsound.sh --help-all 2>&1)
rc=$?
[[ $rc -eq 0 ]] || fail "macOS --help-all exited with $rc"
grep -q 'Usage:' <<<"$out" || fail "macOS --help-all does not print usage"
grep -q 'no bundled installer' <<<"$out" || fail "macOS --help-all does not mention the .pkg"

echo "== macOS path refuses to run without a terminal =="
if command -v setsid >/dev/null 2>&1; then
    dir=$(write_uname Darwin)
    out=$(PATH="$dir:$PATH" setsid bash getcsound.sh </dev/null 2>&1)
    rc=$?
    [[ $rc -ne 0 ]] || fail "macOS path should refuse to run without a terminal"
    grep -qi 'must be run from a terminal' <<<"$out" || fail "macOS refusal message not printed"
else
    echo "   skipped: setsid not available to detach from the terminal"
fi

echo "== unsupported OS is rejected =="
dir=$(write_uname Plan9)
out=$(PATH="$dir:$PATH" bash getcsound.sh 2>&1)
rc=$?
[[ $rc -ne 0 ]] || fail "unsupported OS should exit non-zero"
grep -q 'Unsupported operating system' <<<"$out" || fail "unsupported OS message not printed"

echo "lint tests OK"
