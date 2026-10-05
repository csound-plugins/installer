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
grep -q -- '--release' <<<"$out" || fail "--help does not mention --release"

echo "== --help documents the Linux installation options =="
out=$(bash getcsound.sh --help 2>&1)
rc=$?
[[ $rc -eq 0 ]] || fail "--help exited with $rc"
grep -q -- '--user' <<<"$out" || fail "--help does not mention --user"
grep -q -- '--quiet' <<<"$out" || fail "--help does not mention --quiet"

echo "== unknown option is rejected =="
out=$(bash getcsound.sh --bogus 2>&1)
rc=$?
[[ $rc -ne 0 ]] || fail "unknown option should exit non-zero"
grep -q 'Unknown option' <<<"$out" || fail "unknown option message not printed"

echo "== macOS path refuses to run without a terminal and without passwordless sudo =="
if command -v setsid >/dev/null 2>&1; then
    dir=$(write_uname Darwin)
    nosudo="$WORK/nosudo-$RANDOM"
    mkdir -p "$nosudo"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$nosudo/sudo"
    chmod +x "$nosudo/sudo"
    out=$(PATH="$nosudo:$dir:$PATH" setsid bash getcsound.sh </dev/null 2>&1)
    rc=$?
    [[ $rc -ne 0 ]] || fail "macOS path should refuse to run without a terminal"
    grep -qi 'must be run from a terminal' <<<"$out" || fail "macOS refusal message not printed"
else
    echo "   skipped: setsid not available to detach from the terminal"
fi

echo "== macOS path proceeds without a terminal when sudo is passwordless =="
if command -v setsid >/dev/null 2>&1; then
    dir=$(write_uname Darwin)
    yessudo="$WORK/yessudo-$RANDOM"
    mkdir -p "$yessudo"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$yessudo/sudo"
    chmod +x "$yessudo/sudo"
    # A failing curl stops the script at the API query, before downloading or
    # installing anything, but after the terminal/sudo check.
    nocurl="$WORK/nocurl-$RANDOM"
    mkdir -p "$nocurl"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$nocurl/curl"
    chmod +x "$nocurl/curl"
    out=$(PATH="$yessudo:$nocurl:$dir:$PATH" setsid bash getcsound.sh </dev/null 2>&1)
    if grep -qi 'must be run from a terminal' <<<"$out"; then
        fail "macOS path should not refuse when sudo is passwordless"
    fi
    grep -q 'Looking for the latest successful' <<<"$out" || fail "macOS path did not proceed past the terminal check"
else
    echo "   skipped: setsid not available to detach from the terminal"
fi

# write_curl -> prints a directory holding a fake curl that records its
# arguments (one line per invocation) to the file named by the RECORD env var
# and then fails, so the script stops at the first API query.
write_curl() {
    local dir="$WORK/curl-$RANDOM"
    mkdir -p "$dir"
    cat > "$dir/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RECORD"
exit 1
EOF
    chmod +x "$dir/curl"
    printf '%s\n' "$dir"
}

# write_gh -> prints a directory holding a fake gh that answers
# `gh auth token` with GH_FAKE_TOKEN (empty simulates an unauthenticated gh).
write_gh() {
    local dir="$WORK/gh-$RANDOM"
    mkdir -p "$dir"
    cat > "$dir/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" && "${2:-}" == "token" && -n "${GH_FAKE_TOKEN:-}" ]]; then
    printf '%s\n' "$GH_FAKE_TOKEN"
    exit 0
fi
exit 1
EOF
    chmod +x "$dir/gh"
    printf '%s\n' "$dir"
}

# run_macos_api_probe RECORD [ENVNAME ENVVAL] -> runs the macOS path with a
# fake sudo/curl/gh. All API queries fail, so only the authentication attempt
# is observable (recorded by the fake curl). ENVNAME is a token variable to
# expose to the script under test.
run_macos_api_probe() {
    local record=$1
    local envname=${2:-} envval=${3:-}
    local dir yessudo curldir ghdir
    local -a extra=()
    dir=$(write_uname Darwin)
    yessudo="$WORK/yessudo-$RANDOM"
    mkdir -p "$yessudo"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$yessudo/sudo"
    chmod +x "$yessudo/sudo"
    curldir=$(write_curl)
    ghdir=$(write_gh)
    [[ -n "$envname" ]] && extra+=("$envname=$envval")
    env RECORD="$record" "${extra[@]}" PATH="$yessudo:$ghdir:$curldir:$dir:$PATH" \
        setsid bash getcsound.sh </dev/null >/dev/null 2>&1 || true
}

echo "== macOS API queries use GH_TOKEN from the environment =="
if command -v setsid >/dev/null 2>&1; then
    record="$WORK/record-envtoken-$RANDOM"
    run_macos_api_probe "$record" GH_TOKEN envtok
    grep -q 'Authorization: Bearer envtok' "$record" \
        || fail "API query did not authenticate with GH_TOKEN"
else
    echo "   skipped: setsid not available to detach from the terminal"
fi

echo "== macOS API queries fall back to 'gh auth token' =="
if command -v setsid >/dev/null 2>&1; then
    record="$WORK/record-ghtoken-$RANDOM"
    run_macos_api_probe "$record" GH_FAKE_TOKEN ghtok
    grep -q 'Authorization: Bearer ghtok' "$record" \
        || fail "API query did not use the 'gh auth token' fallback"
else
    echo "   skipped: setsid not available to detach from the terminal"
fi

echo "== macOS API queries stay anonymous without a token =="
if command -v setsid >/dev/null 2>&1; then
    record="$WORK/record-anon-$RANDOM"
    run_macos_api_probe "$record"
    if grep -q 'Authorization' "$record"; then
        fail "anonymous API query must not send an Authorization header"
    fi
else
    echo "   skipped: setsid not available to detach from the terminal"
fi

echo "== unsupported OS is rejected =="
dir=$(write_uname Plan9)
out=$(PATH="$dir:$PATH" bash getcsound.sh 2>&1)
rc=$?
[[ $rc -ne 0 ]] || fail "unsupported OS should exit non-zero"
grep -q 'Unsupported operating system' <<<"$out" || fail "unsupported OS message not printed"

# run_linux_install_smoke -> builds a fake portable archive and stubs curl and
# uname, then runs a user-local, non-interactive install into a temporary HOME
# and checks the result. No network access and no system files are touched.
run_linux_install_smoke() {
    local root="$WORK/linux-$RANDOM"
    local src="$root/src" fake="$root/fake" home="$root/home" zipdir="$root/zip"
    mkdir -p "$src/plugins" "$fake" "$zipdir"

    printf '#!/bin/sh\necho csound\n' > "$src/csound"
    chmod +x "$src/csound"
    printf 'x' > "$src/libcsound64.so.7.0"
    printf 'x' > "$src/plugins/portable.so"
    ( cd "$src" && zip -qr "$zipdir/asset.zip" . )
    sha256sum "$zipdir/asset.zip" | awk '{print $1"  csound7-linux-x86_64.zip"}' > "$zipdir/asset.zip.sha256"

    cat > "$fake/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    -s) echo Linux ;;
    -m) echo x86_64 ;;
    *)  echo Linux ;;
esac
EOF
    # Fake curl: serves the pre-built archive/checksum regardless of URL.
    cat > "$fake/curl" <<'EOF'
#!/usr/bin/env bash
out=""; url=""
while (($#)); do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -*) shift ;;
        *)  url="$1"; shift ;;
    esac
done
case "$url" in
    *.sha256) cp "$FAKE_SHA" "$out" ;;
    *.zip)    cp "$FAKE_ZIP" "$out" ;;
    *) echo "unexpected curl URL: $url" >&2; exit 1 ;;
esac
EOF
    chmod +x "$fake/uname" "$fake/curl"

    if ! env -i HOME="$home" PATH="$fake:/usr/bin:/bin" \
        FAKE_ZIP="$zipdir/asset.zip" FAKE_SHA="$zipdir/asset.zip.sha256" \
        SHELL=/bin/bash TERM=dumb \
        bash getcsound.sh --user -y --no-risset > "$root/out" 2>&1; then
        cat "$root/out" >&2
        fail "Linux install smoke test failed"
    fi

    [[ -x "$home/.local/csound/csound" ]] || fail "csound was not installed"
    [[ -f "$home/.local/csound/libcsound64.so.7.0" ]] || fail "libcsound64.so.7.0 was not installed"
    [[ -f "$home/.local/lib/csound/7.0/plugins64/portable.so" ]] || fail "plugins were not installed"
    grep -q '# Added by Csound 7 installer' "$home/.bashrc" || fail "PATH was not added to the shell config"

    # The quiet mode must suppress the install chatter but keep one completion line.
    if ! env -i HOME="$root/home-quiet" PATH="$fake:/usr/bin:/bin" \
        FAKE_ZIP="$zipdir/asset.zip" FAKE_SHA="$zipdir/asset.zip.sha256" \
        SHELL=/bin/bash TERM=dumb \
        bash getcsound.sh --user -y --no-risset --quiet > "$root/quiet.out" 2>&1; then
        cat "$root/quiet.out" >&2
        fail "Linux quiet install smoke test failed"
    fi
    if grep -q 'Portable Installer' "$root/quiet.out"; then
        fail "quiet mode still prints the installer banner"
    fi
    grep -q 'Csound 7 installed to' "$root/quiet.out" || fail "quiet mode did not print the completion line"
}

echo "== Linux install (user-local, non-interactive) =="
run_linux_install_smoke

echo "lint tests OK"
