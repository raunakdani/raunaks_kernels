# raunaks_kernels

Personal sandbox for writing and testing GPU kernels under GPGPU-Sim before
promoting them to `gpu-app-collection-public`.

## Directory layout

```
raunaks_kernels/
├── gpgpusim.config   # Volta TITAN V (SM70) — GPGPU-Sim picks this up from CWD
├── Makefile          # Builds any .cu file in this directory
├── run.sh            # One-shot compile + run under GPGPU-Sim or on silicon
├── vector_add.cu     # Starter example
└── README.md
```

## Workflow

### 1. Write a kernel

Create a new `.cu` file, e.g. `my_kernel.cu`, directly in this folder.
Each file should be self-contained (kernel + host driver code in one file).

### 2. Build

```bash
# Build a specific kernel
make KERNEL=my_kernel

# Build everything in the folder
make
```

The Makefile compiles for `compute_70 / sm_70` (Volta PTX) so GPGPU-Sim can
simulate it correctly.

### 3. Run (simulator or silicon)

`run.sh` runs a kernel either under GPGPU-Sim or on a real GPU. Pass `sim` or
`silicon` as the second argument to pick the target:

```bash
./run.sh <design> sim        # run <design> under GPGPU-Sim
./run.sh <design> silicon    # run <design> on real GPU hardware
```

Full form (the mode defaults to `sim` if omitted):

```bash
./run.sh <kernel_name> [sim|silicon] [kernel args...]
```

| Command | Where it runs |
|---------|---------------|
| `./run.sh my_kernel`          | GPGPU-Sim (default) |
| `./run.sh my_kernel sim`      | GPGPU-Sim (explicit) |
| `./run.sh my_kernel silicon`  | Real GPU hardware (no simulator) |
| `./run.sh my_kernel sim 1024` | GPGPU-Sim + kernel arg `1024` |

Examples with the `bar_sync` test kernel:

```bash
./run.sh bar_sync            # simulate the bar.sync barrier under GPGPU-Sim
./run.sh bar_sync silicon    # run the same binary on a real GPU to compare
```

**Simulator mode (`sim`, default)** — `run.sh` will:
1. Build the binary if missing or stale.
2. `source` GPGPU-Sim's `setup_environment`, which points `LD_LIBRARY_PATH`
   at the intercepting `libcudart.so`.
3. `cd` into this directory so `gpgpusim.config` is picked up from the CWD.
4. Execute the binary — GPGPU-Sim takes over and simulates execution.

**Silicon mode (`silicon`)** — `run.sh` strips any GPGPU-Sim paths out of
`LD_LIBRARY_PATH` so the *real* CUDA runtime is used, then executes the binary
directly on the GPU. Use this to sanity-check that a kernel produces the same
result on hardware as it does in the simulator (`gpgpusim.config` is ignored).

### 4. Promote a validated kernel

Once a kernel passes simulation, copy or move it to
`gpu-app-collection-public/src/cuda/` and add a proper Makefile there.

## Configuration

`gpgpusim.config` models the **Volta TITAN V (SM 7.0)**. To simulate a
different GPU, replace it with one of the tested configs from:

```
../gpgpu-sim_distribution-funtional/configs/tested-cfgs/
```

Available tested configs:
- `SM2_GTX480`, `SM3_KEPLER_TITAN`, `SM6_TITANX`
- `SM75_RTX2060`, `SM75_RTX2060_S`
- `SM7_GV100`, `SM7_QV100`, **`SM7_TITANV`** ← current
- `SM80_A100`, `SM86_RTX3070`, `SM90_H100`

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GPGPUSIM_ROOT` | `~/gpu_research/gpgpu-sim_distribution-funtional` | Path to GPGPU-Sim |
| `CUDA_INSTALL_PATH` | `/usr/local/cuda` | Path to CUDA toolkit |
