#!/usr/bin/env bash
#
# setup.sh — bootstrap the python-serv environment.
#
#   Creates (or reuses) a virtualenv, upgrades pip/setuptools/wheel, then
#   installs the packages from requirements.txt.
#
#   The tricky dependency is `uuid-utils`: a Rust/maturin package pulled in
#   transitively by langchain-core and langsmith. It has no prebuilt wheel for
#   Android, so on Termux pip tries to compile it from source and usually
#   fails (missing system linkers / outdated cargo toolchain). This script
#   resolves it two ways, in order:
#
#   1) NATIVE BUILD — install the Rust toolchain first
#        pkg update && pkg install rust clang binutils python -y
#        pip install --upgrade pip setuptools wheel
#        pip install uuid-utils
#      (the script does this automatically on Termux when you pass
#       ALLOW_RUST_INSTALL=1, or prompts when run interactively)
#
#   2) STD LIB BYPASS — no Rust required. If the native build still fails
#      (or no toolchain is available), the script installs a fake
#      `uuid-utils` distribution whose package is backed entirely by Python's
#      built-in `uuid` module. pip then treats the dependency as satisfied
#      and skips the native build; `import uuid_utils` still works.
#
#   `lxml` is the other build nightmare on Termux: python-docx depends on it,
#   and pip would try to compile it from source against libxml2/libxslt. The
#   script prefers the precompiled Termux package and only falls back to a
#   from-source build if needed:
#
#   1) TERMUX APT (fastest) — install the native package and let the venv see
#      it via --system-site-packages:
#        pkg install python-lxml -y
#        python -m venv --system-site-packages .venv
#
#   2) PIP BUILD (last resort) — install system libs + inject build flags:
#        pkg install libxml2 libxslt pkg-config clang make -y
#        pip install cython wheel
#        STATIC_DEPS=true pip install lxml
#        CFLAGS="-Wno-error=incompatible-function-pointer-types -O0" pip install lxml
#
# Usage:
#   ./setup.sh [requirements.txt]
#   ALLOW_RUST_INSTALL=1 ./setup.sh        # auto-install rust on Termux
#   SKIP_UUID_SHIM=1    ./setup.sh         # never create the stdlib shim
#   SKIP_LXML=1         ./setup.sh         # skip Termux python-lxml handling
#   VENV_DIR=/custom/path ./setup.sh
#   PYTHON=python3 ./setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ="${1:-$SCRIPT_DIR/requirements.txt}"
VENV_DIR="${VENV_DIR:-$SCRIPT_DIR/env}"
PYTHON="${PYTHON:-}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[!]\033[0m %s\n' "$*" >&2; exit 1; }

is_termux() { [[ -n "${PREFIX:-}" && -d "$PREFIX" ]]; }

find_python() {
    if [[ -n "$PYTHON" ]] && command -v "$PYTHON" >/dev/null 2>&1; then
        printf '%s\n' "$PYTHON"
    elif command -v python3 >/dev/null 2>&1; then
        printf 'python3\n'
    elif command -v python >/dev/null 2>&1; then
        printf 'python\n'
    else
        die "No Python found. Install it first (Termux: 'pkg install python')."
    fi
}

# ---------------------------------------------------------------------------
# Stdlib-backed uuid_utils shim
# ---------------------------------------------------------------------------
install_uuid_shim() {
    local py="$1"
    local sp
    sp="$("$py" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
    local pkg="$sp/uuid_utils"
    local dist="$sp/uuid_utils-0.17.0.dist-info"

    log "uuid-utils native build failed — installing stdlib uuid shim into:"
    log "  $pkg"
    mkdir -p "$pkg" "$dist"

    cat > "$pkg/__init__.py" <<'PY'
"""Pure-Python stand-in for uuid_utils (Rust) using the stdlib uuid module.

Installed by setup.sh when the native Rust build is unavailable (e.g. Termux).
Only the API surface used by langchain-core is guaranteed; uuid6/7/8 are
minimal RFC 9562 implementations because the stdlib has no v6/v7/v8.
"""
from uuid import (
    UUID,
    NAMESPACE_DNS,
    NAMESPACE_OID,
    NAMESPACE_URL,
    NAMESPACE_X500,
    RESERVED_FUTURE,
    RESERVED_MICROSOFT,
    RESERVED_NCS,
    RFC_4122,
    SafeUUID,
    getnode,
    uuid1,
    uuid3,
    uuid4,
    uuid5,
)

from .compat import uuid6, uuid7, uuid8

__version__ = "0.17.0"
# NIL/MAX are module-level only in Python >= 3.13; define them here so the
# shim exposes the full uuid_utils surface on older interpreters too.
NIL = UUID(int=0)
MAX = UUID(int=(1 << 128) - 1)

__all__ = [
    "MAX",
    "NAMESPACE_DNS",
    "NAMESPACE_OID",
    "NAMESPACE_URL",
    "NAMESPACE_X500",
    "NIL",
    "RESERVED_FUTURE",
    "RESERVED_MICROSOFT",
    "RESERVED_NCS",
    "RFC_4122",
    "UUID",
    "SafeUUID",
    "__version__",
    "getnode",
    "uuid1",
    "uuid3",
    "uuid4",
    "uuid5",
    "uuid6",
    "uuid7",
    "uuid8",
]
PY

    cat > "$pkg/compat.py" <<'PY'
"""Minimal RFC 9562 UUIDv6/v7/v8 helpers (stdlib has none of these)."""
import os
import time
from uuid import UUID


def _timed(version, timestamp, nanos):
    if timestamp is not None:
        ts_ms = timestamp * 1000 + ((nanos or 0) // 1_000_000)
    else:
        ts_ms = time.time_ns() // 1_000_000
    b = bytearray(os.urandom(16))
    b[:6] = ts_ms.to_bytes(6, "big")
    b[6] = (b[6] & 0x0F) | (version << 4)
    b[8] = (b[8] & 0x3F) | 0x80
    return UUID(bytes=bytes(b))


def uuid6(timestamp=None, nanos=None):
    return _timed(6, timestamp, nanos)


def uuid7(timestamp=None, nanos=None):
    return _timed(7, timestamp, nanos)


def uuid8(timestamp=None, nanos=None):
    return _timed(8, timestamp, nanos)
PY

    cat > "$dist/METADATA" <<'MD'
Metadata-Version: 2.1
Name: uuid-utils
Version: 0.17.0
Summary: Pure-Python shim for uuid-utils (stdlib uuid), installed by setup.sh
MD

    cat > "$dist/top_level.txt" <<'TXT'
uuid_utils
TXT
    printf 'setup.sh\n' > "$dist/INSTALLER"
    cat > "$dist/RECORD" <<'REC'
uuid_utils/__init__.py,,
uuid_utils/compat.py,,
uuid_utils-0.17.0.dist-info/METADATA,,
uuid_utils-0.17.0.dist-info/top_level.txt,,
uuid_utils-0.17.0.dist-info/INSTALLER,,
uuid_utils-0.17.0.dist-info/RECORD,,
REC

    log "Shim installed. Verifying:"
    "$py" -c 'from uuid_utils import uuid4, uuid7; from uuid_utils.compat import uuid7 as c7; assert str(uuid7()).split("-")[2][0] == "7"; assert str(c7()).split("-")[2][0] == "7"; print("uuid_utils shim OK — uuid4:", uuid4())'
}

install_rust_toolchain() {
    if ! is_termux; then
        die "Not running under Termux; install a Rust toolchain yourself (cargo/rustc)."
    fi
    if [[ "${ALLOW_RUST_INSTALL:-}" != "1" ]] && [[ ! -t 0 ]]; then
        warn "Non-interactive shell — skipping automatic 'pkg install rust'. Use ALLOW_RUST_INSTALL=1 to force."
        return 1
    fi
    if [[ "${ALLOW_RUST_INSTALL:-}" != "1" ]]; then
        printf 'Install Rust + build tools via pkg? [y/N] ' >&2
        read -r ans
        [[ "$ans" =~ ^[Yy]$ ]] || return 1
    fi
    log "Installing Rust + build tools (pkg update && pkg install rust clang binutils)"
    pkg update && pkg install -y rust clang binutils
}

# ---------------------------------------------------------------------------
# lxml handling (python-docx -> lxml) on Termux
# ---------------------------------------------------------------------------
# Returns:
#   0  lxml importable (native pkg install succeeded, or already present)
#   1  no pkg available / non-Termux / pkg install failed
#   2  python-lxml installed by pkg but NOT visible inside the venv
install_lxml_termux() {
    if ! is_termux || [[ "${SKIP_LXML:-}" == "1" ]]; then
        return 1
    fi
    if "$VENV_PY" -c 'import lxml.etree' >/dev/null 2>&1; then
        log "lxml already importable in the venv"
        return 0
    fi
    if ! command -v pkg >/dev/null 2>&1; then
        warn "pkg not available — cannot install python-lxml via apt."
        return 1
    fi
    log "Installing precompiled python-lxml via pkg (avoids the painful C build)"
    if pkg install -y python-lxml; then
        if "$VENV_PY" -c 'import lxml.etree' >/dev/null 2>&1; then
            log "lxml available via system site-packages"
            return 0
        fi
        warn "python-lxml installed, but the venv cannot see it (needs --system-site-packages)."
        return 2
    fi
    return 1
}

# Last-resort from-source build for lxml (Termux apt unavailable / not visible).
try_pip_build_lxml() {
    if is_termux; then
        log "Installing lxml build deps (libxml2 libxslt pkg-config clang make)"
        pkg install -y libxml2 libxslt pkg-config clang make || return 1
    fi
    log "Installing cython + wheel"
    "$VENV_PY" -m pip install --upgrade cython wheel
    if STATIC_DEPS=true "$VENV_PY" -m pip install lxml; then
        return 0
    fi
    warn "STATIC_DEPS=true build failed — retrying with relaxed CFLAGS"
    CFLAGS="-Wno-error=incompatible-function-pointer-types -O0" "$VENV_PY" -m pip install lxml
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
[[ -f "$REQ" ]] || die "requirements file not found: $REQ"

PY="$(find_python)"
if is_termux && ! "$PY" -c 'import venv' >/dev/null 2>&1; then
    log "Installing python-venv on Termux"
    pkg install -y python-venv
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    log "Creating virtualenv: $VENV_DIR"
    if is_termux; then
        "$PY" -m venv --system-site-packages "$VENV_DIR"
    else
        "$PY" -m venv "$VENV_DIR"
    fi
else
    log "Reusing existing virtualenv: $VENV_DIR"
    if is_termux && ! grep -q 'include-system-site-packages = true' "$VENV_DIR/pyvenv.cfg" 2>/dev/null; then
        warn "Existing venv lacks --system-site-packages — recreating it so Termux "
        warn "pkg packages (e.g. python-lxml) are visible."
        rm -rf "$VENV_DIR"
        "$PY" -m venv --system-site-packages "$VENV_DIR"
    fi
fi
VENV_PY="$VENV_DIR/bin/python"

log "Upgrading pip, setuptools, wheel"
"$VENV_PY" -m pip install --upgrade pip setuptools wheel

if is_termux; then
    install_lxml_termux || true
fi

PIP_LOG="$SCRIPT_DIR/.setup-pip.log"
if ! "$VENV_PY" -m pip install -r "$REQ" 2>&1 | tee "$PIP_LOG"; then
    warn "Initial 'pip install -r $REQ' failed — see $PIP_LOG"
    if grep -qiE 'lxml|libxml2?|failed to build wheel for lxml' "$PIP_LOG"; then
        warn "Looks like an lxml native-build failure — trying the from-source fix."
        try_pip_build_lxml || warn "lxml pip-build fallback failed; continuing."
    fi
    if ! is_termux && ! command -v cargo >/dev/null 2>&1 && [[ "${SKIP_UUID_SHIM:-}" != "1" ]]; then
        # Not on Termux but no Rust toolchain either — likely a uuid-utils
        # build failure, so go straight to the stdlib shim.
        if ! install_uuid_shim "$VENV_PY"; then
            die "Shim install failed; see output above."
        fi
    elif is_termux; then
        if command -v cargo >/dev/null 2>&1; then
            warn "cargo present but build still failed — trying the stdlib shim instead."
            install_uuid_shim "$VENV_PY"
        else
            warn "Termux detected with no Rust toolchain."
            if install_rust_toolchain; then
                log "Retrying install with native Rust toolchain"
                if "$VENV_PY" -m pip install -r "$REQ"; then
                    :
                elif [[ "${SKIP_UUID_SHIM:-}" != "1" ]]; then
                    warn "Native build still failing — installing stdlib shim."
                    install_uuid_shim "$VENV_PY"
                fi
            elif [[ "${SKIP_UUID_SHIM:-}" != "1" ]]; then
                install_uuid_shim "$VENV_PY"
            else
                die "uuid-utils could not be built and shim was skipped (SKIP_UUID_SHIM=1)."
            fi
        fi
    elif [[ "${SKIP_UUID_SHIM:-}" != "1" ]]; then
        install_uuid_shim "$VENV_PY"
    else
        die "pip install failed and shim was skipped (SKIP_UUID_SHIM=1)."
    fi

    log "Re-running 'pip install -r $REQ' after uuid-utils resolution"
    "$VENV_PY" -m pip install -r "$REQ"
fi

log "Verifying imports"
"$VENV_PY" -c 'import flask, langchain_core, langgraph, lxml.etree, docx; print("langchain stack + lxml/docx imports OK")'

printf '\033[1;32m\nSetup complete. Activate with:\n    source %s/bin/activate\n\033[0m' "$VENV_DIR"
