#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VENV_PYTHON="$SCRIPT_DIR/venv/bin/python"

die() {
    printf '[run-linux] ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(uname -s)" == "Linux" ]] || die "This launcher only supports Linux."
cd "$SCRIPT_DIR"

if [[ ! -x "$VENV_PYTHON" ]]; then
    printf '[run-linux] No virtual environment found; starting installation...\n'
    [[ -f "$SCRIPT_DIR/install_linux.sh" ]] || die "install_linux.sh is missing."
    bash "$SCRIPT_DIR/install_linux.sh"
fi

[[ -f "$SCRIPT_DIR/run.py" ]] || die "run.py is missing. Extract the complete release archive."

has_provider=0
has_language=0
for arg in "$@"; do
    case "$arg" in
        --execution-provider|--execution-provider=*) has_provider=1 ;;
        -l|--lang|--lang=*) has_language=1 ;;
    esac
done

launch_args=()
if [[ "$has_provider" -eq 0 ]]; then
    provider="${DLC_EXECUTION_PROVIDER:-auto}"
    if [[ "$provider" == "auto" ]]; then
        provider="cpu"
        if command -v nvidia-smi >/dev/null 2>&1 && \
           nvidia-smi -L >/dev/null 2>&1 && \
           "$VENV_PYTHON" -c 'import onnxruntime as ort; raise SystemExit(0 if "CUDAExecutionProvider" in ort.get_available_providers() else 1)' 2>/dev/null; then
            provider="cuda"
        fi
    fi
    launch_args+=(--execution-provider "$provider")
    printf '[run-linux] Execution provider: %s\n' "$provider"
fi

if [[ "$has_language" -eq 0 ]]; then
    launch_args+=(-l "${DLC_LANG:-zh}")
fi

exec "$VENV_PYTHON" "$SCRIPT_DIR/run.py" "${launch_args[@]}" "$@"
