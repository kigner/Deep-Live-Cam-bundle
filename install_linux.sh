#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
VENV_PYTHON="$VENV_DIR/bin/python"

log() {
    printf '[install-linux] %s\n' "$*"
}

die() {
    printf '[install-linux] ERROR: %s\n' "$*" >&2
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

root_command() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        die "Root access is required for system packages, but sudo is not installed."
    fi
}

install_system_dependencies() {
    if [[ "${DLC_SKIP_SYSTEM_DEPS:-0}" == "1" ]]; then
        log "Skipping system packages because DLC_SKIP_SYSTEM_DEPS=1."
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        log "Installing system packages with apt..."
        root_command apt-get update
        root_command apt-get install -y \
            python3 python3-dev python3-venv python3-pip \
            build-essential ffmpeg libgl1 libglib2.0-0 \
            libxcb-cursor0 libxkbcommon-x11-0 zlib1g
    elif command -v dnf >/dev/null 2>&1; then
        log "Installing system packages with dnf..."
        root_command dnf install -y \
            python3 python3-devel python3-pip gcc gcc-c++ make \
            ffmpeg mesa-libGL glib2 libxcb libxkbcommon-x11 xcb-util-cursor zlib
    elif command -v pacman >/dev/null 2>&1; then
        log "Installing system packages with pacman..."
        root_command pacman -Sy --needed --noconfirm \
            python python-pip base-devel ffmpeg mesa \
            libxkbcommon-x11 libxcb xcb-util-cursor zlib
    elif command -v zypper >/dev/null 2>&1; then
        log "Installing system packages with zypper..."
        root_command zypper --non-interactive install \
            python311 python311-devel python311-pip gcc gcc-c++ make \
            ffmpeg Mesa-libGL1 libglib-2_0-0 libxcb1 libxkbcommon-x11-0 zlib
    elif ! command -v ffmpeg >/dev/null 2>&1 || ! command -v cc >/dev/null 2>&1; then
        die "Unsupported package manager. Install Python 3.10-3.13, FFmpeg, a C/C++ compiler, and Qt/XCB runtime libraries, then rerun with DLC_SKIP_SYSTEM_DEPS=1."
    else
        log "No supported package manager found; using the existing system dependencies."
    fi
}

find_compatible_python() {
    local candidate
    for candidate in python3.11 python3.12 python3.10 python3.13 python3; do
        if command -v "$candidate" >/dev/null 2>&1 && \
           "$candidate" -c 'import sys; raise SystemExit(0 if (3, 10) <= sys.version_info[:2] < (3, 14) else 1)' 2>/dev/null; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

[[ "$(uname -s)" == "Linux" ]] || die "This installer only supports Linux."
require_release_layout
install_system_dependencies

command -v ffmpeg >/dev/null 2>&1 || die "FFmpeg was not installed successfully."

PYTHON_BIN="$(find_compatible_python || true)"
[[ -n "$PYTHON_BIN" ]] || die \
    "No compatible Python was found. Install Python 3.11 (recommended), including its venv and development packages."

if [[ -e "$VENV_DIR" && ! -x "$VENV_PYTHON" ]]; then
    die "The existing 'venv' is not a Linux virtual environment. Rename or remove it, then rerun this script."
fi

if [[ -x "$VENV_PYTHON" ]]; then
    if ! "$VENV_PYTHON" -c 'import sys; raise SystemExit(0 if (3, 10) <= sys.version_info[:2] < (3, 14) else 1)'; then
        VENV_VERSION="$($VENV_PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
        die "The existing venv uses unsupported Python $VENV_VERSION. Rename or remove venv, then rerun."
    fi
    log "Reusing the existing virtual environment."
else
    log "Creating the Python virtual environment with $PYTHON_BIN..."
    if ! "$PYTHON_BIN" -m venv "$VENV_DIR"; then
        die "Could not create venv. Install the venv package matching $PYTHON_BIN, then rerun."
    fi
fi

log "Updating Python packaging tools..."
"$VENV_PYTHON" -m pip install --upgrade pip setuptools wheel

log "Installing project dependencies (this can take several minutes)..."
"$VENV_PYTHON" -m pip install -r "$SCRIPT_DIR/requirements.txt"

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    log "Installing the CUDA 12 and cuDNN runtime libraries for the detected NVIDIA GPU..."
    "$VENV_PYTHON" -m pip install 'onnxruntime-gpu[cuda,cudnn]==1.23.2'
fi

log "Verifying the installation..."
"$VENV_PYTHON" - <<'PY'
import cv2
import insightface
import numpy
import onnxruntime
import PySide6

print("[install-linux] Python dependencies are ready.")
print("[install-linux] ONNX providers:", ", ".join(onnxruntime.get_available_providers()))
PY

chmod +x \
    "$SCRIPT_DIR/install_macos.sh" \
    "$SCRIPT_DIR/install_linux.sh" \
    "$SCRIPT_DIR/run_macos.command" \
    "$SCRIPT_DIR/run_linux.sh" 2>/dev/null || true

log "Installation complete. Start the app with ./run_linux.sh"
if command -v nvidia-smi >/dev/null 2>&1; then
    log "NVIDIA GPU detected. CUDA is selected automatically when ONNX Runtime exposes it."
else
    log "No NVIDIA driver was detected; the one-click launcher will use CPU mode."
fi
