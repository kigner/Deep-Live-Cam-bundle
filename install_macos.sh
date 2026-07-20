#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
VENV_PYTHON="$VENV_DIR/bin/python"

log() {
    printf '[install-macos] %s\n' "$*"
}

die() {
    printf '[install-macos] ERROR: %s\n' "$*" >&2
    exit 1
}

require_release_layout() {
    local path
    for path in run.py requirements.txt locales modules models; do
        [[ -e "$SCRIPT_DIR/$path" ]] || die "Missing '$path'. Extract the complete release archive first."
    done

    if [[ ! -f "$SCRIPT_DIR/models/inswapper_128.onnx" && \
          ! -f "$SCRIPT_DIR/models/inswapper_128_fp16.onnx" ]]; then
        die "Missing models/inswapper_128.onnx (or the FP16 variant)."
    fi

    for path in det_10g.onnx w600k_r50.onnx 2d106det.onnx; do
        [[ -f "$SCRIPT_DIR/models/insightface/models/buffalo_l/$path" ]] || \
            die "Missing models/insightface/models/buffalo_l/$path."
    done
}

ensure_homebrew() {
    command -v brew >/dev/null 2>&1 || die \
        "Homebrew is required to install missing system packages. Install it from https://brew.sh and rerun this script."
}

find_python311() {
    local candidate
    for candidate in python3.11 /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do
        if command -v "$candidate" >/dev/null 2>&1 && \
           "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 11) else 1)' 2>/dev/null; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

[[ "$(uname -s)" == "Darwin" ]] || die "This installer only supports macOS."
require_release_layout

if ! xcode-select -p >/dev/null 2>&1; then
    log "Apple Command Line Tools are required to build Python dependencies."
    xcode-select --install >/dev/null 2>&1 || true
    die "Complete the Command Line Tools installation, then run this script again."
fi

PYTHON_BIN="$(find_python311 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
    ensure_homebrew
    log "Installing Python 3.11 with Homebrew..."
    brew install python@3.11
    PYTHON_BIN="$(find_python311 || true)"
    [[ -n "$PYTHON_BIN" ]] || die "Python 3.11 was installed but its executable could not be found."
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    ensure_homebrew
    log "Installing FFmpeg with Homebrew..."
    brew install ffmpeg
fi

if [[ -e "$VENV_DIR" && ! -x "$VENV_PYTHON" ]]; then
    die "The existing 'venv' is not a macOS virtual environment. Rename or remove it, then rerun this script."
fi

if [[ -x "$VENV_PYTHON" ]]; then
    VENV_VERSION="$($VENV_PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    [[ "$VENV_VERSION" == "3.11" ]] || die \
        "The existing venv uses Python $VENV_VERSION; this macOS bundle requires Python 3.11. Rename or remove venv, then rerun."
    log "Reusing the existing Python 3.11 virtual environment."
else
    log "Creating Python 3.11 virtual environment..."
    "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

log "Updating Python packaging tools..."
"$VENV_PYTHON" -m pip install --upgrade pip setuptools wheel

log "Installing project dependencies (this can take several minutes)..."
"$VENV_PYTHON" -m pip install -r "$SCRIPT_DIR/requirements.txt"

# requirements.txt installs onnxruntime-silicon on Apple Silicon. Intel Macs
# need the regular CPU package because the silicon marker intentionally skips it.
if [[ "$(uname -m)" == "x86_64" ]] && \
   ! "$VENV_PYTHON" -c 'import onnxruntime' >/dev/null 2>&1; then
    log "Installing ONNX Runtime for Intel Mac..."
    "$VENV_PYTHON" -m pip install 'onnxruntime==1.23.2'
fi

log "Verifying the installation..."
"$VENV_PYTHON" - <<'PY'
import cv2
import insightface
import numpy
import onnxruntime
import PySide6

print("[install-macos] Python dependencies are ready.")
print("[install-macos] ONNX providers:", ", ".join(onnxruntime.get_available_providers()))
PY

chmod +x \
    "$SCRIPT_DIR/install_macos.sh" \
    "$SCRIPT_DIR/install_linux.sh" \
    "$SCRIPT_DIR/run_macos.command" \
    "$SCRIPT_DIR/run_linux.sh" 2>/dev/null || true

log "Installation complete. Double-click run_macos.command, or run it from Terminal."
