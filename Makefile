GPGPUSIM_ROOT ?= $(HOME)/gpu_research/gpgpu-sim_distribution-funtional
CUDA_INSTALL_PATH ?= /usr/local/cuda

NVCC     := $(CUDA_INSTALL_PATH)/bin/nvcc
GCC      := g++

# Compile for Hopper PTX (SM90) — required for SM90 instructions like elect.sync.
# Also embed PTX so GPGPU-Sim can intercept and simulate it.
ARCH     := -gencode arch=compute_90,code=compute_90 \
            -gencode arch=compute_90,code=sm_90

NVCC_FLAGS := $(ARCH) -O2 -std=c++14 -Xptxas -v

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
