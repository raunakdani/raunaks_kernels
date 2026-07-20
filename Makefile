GPGPUSIM_ROOT ?= $(HOME)/gpu_research/gpgpu-sim_distribution-funtional
# Prefer the CUDA toolkit that matches the built GPGPU-Sim libcudart
# (lib/gcc-*/cuda-12080/). /usr/local/cuda currently points at 13.0, which
# has no matching simulator build in this tree.
CUDA_INSTALL_PATH ?= /usr/local/cuda-12.8

NVCC     := $(CUDA_INSTALL_PATH)/bin/nvcc
GCC      := g++

# Compile for Hopper PTX (SM90) — required for SM90 instructions like elect.sync.
# Also embed PTX so GPGPU-Sim can intercept and simulate it.
#
# -cudart=shared is REQUIRED for simulator runs: nvcc's default static cudart
# bakes the real NVIDIA runtime into the binary, so LD_LIBRARY_PATH can never
# intercept and "sim" silently executes on silicon.
ARCH     := -gencode arch=compute_90,code=compute_90 \
            -gencode arch=compute_90,code=sm_90

NVCC_FLAGS := $(ARCH) -O2 -std=c++14 -Xptxas -v -cudart=shared

# Build a single kernel: make KERNEL=<basename>  (e.g. make KERNEL=vector_add)
ifdef KERNEL
all: $(KERNEL)

$(KERNEL): $(KERNEL).cu
	$(NVCC) $(NVCC_FLAGS) -o $@ $<
	@echo "Built: $@"

clean:
	rm -f $(KERNEL)

else
# Build all .cu files in the directory when no KERNEL is specified
SOURCES := $(wildcard *.cu)
TARGETS := $(SOURCES:.cu=)

all: $(TARGETS)

%: %.cu
	$(NVCC) $(NVCC_FLAGS) -o $@ $<
	@echo "Built: $@"

clean:
	rm -f $(TARGETS)
endif

.PHONY: all clean
