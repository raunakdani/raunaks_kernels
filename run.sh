#!/usr/bin/env bash
# run.sh — compile (if needed) and execute a kernel under GPGPU-Sim or on
# real GPU hardware (silicon).
#
# Usage:
#   ./run.sh <kernel_name> [sim|silicon] [kernel args...]
#
# Examples:
#   ./run.sh vector_add                 # simulator (default)
#   ./run.sh vector_add sim             # simulator (explicit)
#   ./run.sh vector_add silicon         # real GPU hardware, no simulator
#   ./run.sh matrix_mul sim 1024        # simulator + kernel arg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GPGPUSIM_ROOT="${GPGPUSIM_ROOT:-${HOME}/gpu_research/gpgpu-sim_distribution-funtional}"
CUDA_INSTALL_PATH="${CUDA_INSTALL_PATH:-/usr/local/cuda}"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <kernel_name> [sim|silicon] [args...]"
    exit 1
fi

KERNEL="$1"; shift

# Optional second argument: sim (default) or silicon (real GPU)
SILICON=0
BUILD_TYPE="release"
if [[ $# -gt 0 ]]; then
    case "$1" in
        sim)
            shift ;;
        silicon)
            SILICON=1; shift ;;
    esac
fi
KERNEL_ARGS=("$@")

# ── Build kernel if missing or stale ─────────────────────────────────────────
if [[ ! -f "${SCRIPT_DIR}/${KERNEL}" ]] || \
   [[ "${SCRIPT_DIR}/${KERNEL}.cu" -nt "${SCRIPT_DIR}/${KERNEL}" ]]; then
    echo "==> Building ${KERNEL}..."
    make -C "${SCRIPT_DIR}" KERNEL="${KERNEL}"
fi

if [[ "${SILICON}" -eq 1 ]]; then
    # ── Run on real GPU hardware ──────────────────────────────────────────────
    # Strip any GPGPU-Sim paths from LD_LIBRARY_PATH so the real CUDA runtime
    # is used instead of the simulator's intercepting libcudart.
    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        CLEAN_LD_PATH=""
        while IFS= read -r -d ':' entry; do
            [[ "${entry}" == *gpgpu-sim* ]] && continue
            [[ "${entry}" == *gpgpusim* ]]  && continue
            CLEAN_LD_PATH="${CLEAN_LD_PATH:+${CLEAN_LD_PATH}:}${entry}"
        done <<< "${LD_LIBRARY_PATH}:"
        export LD_LIBRARY_PATH="${CLEAN_LD_PATH}"
    fi

    echo ""
    echo "==> Running '${KERNEL}' on silicon (real GPU)"
    echo ""
else
    # ── Source GPGPU-Sim's own setup_environment ──────────────────────────────
    # This sets LD_LIBRARY_PATH to the correct lib/gcc-X/cuda-Y/<build_type>
    # path. Pass "debug" as argument to use the debug build.
    export CUDA_INSTALL_PATH
    export OPENCL_REMOTE_GPU_HOST="${OPENCL_REMOTE_GPU_HOST:-}"  # prevent unbound variable error
    set +u  # setup_environment references variables that may be unset
    source "${GPGPUSIM_ROOT}/setup_environment" "${BUILD_TYPE}"
    set -u

    echo ""
    echo "==> Running '${KERNEL}' under GPGPU-Sim (${BUILD_TYPE} build)"
    echo "    Config : ${SCRIPT_DIR}/gpgpusim.config"
    echo ""
fi

cd "${SCRIPT_DIR}"
exec "./${KERNEL}" "${KERNEL_ARGS[@]+"${KERNEL_ARGS[@]}"}"
