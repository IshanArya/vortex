CFLAGS += -std=c++11 -O2 -Wall -Wextra -Wfatal-errors
#CFLAGS += -std=c++11 -g -O0 -Wall -Wextra -Wfatal-errors

CFLAGS += -Wno-aligned-new -Wno-maybe-uninitialized

CFLAGS += -I../../../../hw

# control RTL debug print states
DBG_PRINT_FLAGS += -DDBG_PRINT_PIPELINE  
DBG_PRINT_FLAGS += -DDBG_PRINT_CORE_ICACHE
DBG_PRINT_FLAGS += -DDBG_PRINT_CORE_DCACHE
DBG_PRINT_FLAGS += -DDBG_PRINT_CACHE_BANK 
DBG_PRINT_FLAGS += -DDBG_PRINT_CACHE_MSHR
DBG_PRINT_FLAGS += -DDBG_PRINT_CACHE_TAG
DBG_PRINT_FLAGS += -DDBG_PRINT_CACHE_DATA
DBG_PRINT_FLAGS += -DDBG_PRINT_DRAM
DBG_PRINT_FLAGS += -DDBG_PRINT_OPAE
DBG_PRINT_FLAGS += -DDBG_PRINT_AVS
DBG_PRINT_FLAGS += -DDBG_PRINT_SCOPE

DBG_FLAGS += $(DBG_PRINT_FLAGS)
DBG_FLAGS += -DDBG_CACHE_REQ_INFO

#CONFIGS ?= -DNUM_CLUSTERS=2 -DNUM_CORES=4 -DL2_ENABLE=1
#CONFIGS ?= -DNUM_CLUSTERS=1 -DNUM_CORES=4 -DL2_ENABLE=1
#CONFIGS ?= -DNUM_CLUSTERS=1 -DNUM_CORES=2 -DL2_ENABLE=0
CONFIGS ?= -DNUM_CLUSTERS=1 -DNUM_CORES=1

CFLAGS += -fPIC

CFLAGS += -DUSE_VLSIM $(CONFIGS)

CFLAGS += -DDUMP_PERF_STATS

LDFLAGS += -shared -pthread
# LDFLAGS += -dynamiclib -pthread

TOP = vortex_afu_shim

RTL_DIR=../../../hw/rtl
DPI_DIR=../../../hw/dpi

SRCS = fpga.cpp opae_sim.cpp
SRCS += $(DPI_DIR)/util_dpi.cpp $(DPI_DIR)/float_dpi.cpp

FPU_INCLUDE = -I$(RTL_DIR)/fp_cores -I$(DPI_DIR) -I$(RTL_DIR)/fp_cores/fpnew/src/common_cells/include -I$(RTL_DIR)/fp_cores/fpnew/src/common_cells/src -I$(RTL_DIR)/fp_cores/fpnew/src/fpu_div_sqrt_mvp/hdl -I$(RTL_DIR)/fp_cores/fpnew/src
RTL_INCLUDE = -I$(RTL_DIR) -I$(RTL_DIR)/libs -I$(RTL_DIR)/interfaces -I$(RTL_DIR)/cache $(FPU_INCLUDE)
RTL_INCLUDE += -I$(RTL_DIR)/afu -I$(RTL_DIR)/afu/ccip

VL_FLAGS += -O2 --language 1800-2009 --assert -Wall -Wpedantic $(CONFIGS)
VL_FLAGS += -Wno-DECLFILENAME
VL_FLAGS += --x-initial unique --x-assign unique
VL_FLAGS += verilator.vlt

# Enable Verilator multithreaded simulation
#THREADS ?= $(shell python3 -c 'import multiprocessing as mp; print(max(1, mp.cpu_count() // 2))')
#VL_FLAGS += --threads $(THREADS)

# Debugigng
ifdef DEBUG
	VL_FLAGS += -DVCD_OUTPUT --trace --trace-structs $(DBG_FLAGS)
	CFLAGS   += -DVCD_OUTPUT $(DBG_FLAGS)
else    
	VL_FLAGS += -DNDEBUG
	CFLAGS   += -DNDEBUG
endif

# Enable scope analyzer
ifdef SCOPE
	VL_FLAGS += -DSCOPE
	CFLAGS += -DSCOPE
endif

# Enable perf counters
ifdef PERF
	VL_FLAGS += -DPERF_ENABLE
	CFLAGS += -DPERF_ENABLE
endif

# use our OPAE shim
VL_FLAGS += -DNOPAE
CFLAGS += -DNOPAE

# use DPI FPU
VL_FLAGS += -DFPU_DPI

PROJECT = libopae-c-vlsim.so

all: $(PROJECT)
	
$(PROJECT): $(SRCS)
	verilator --exe --cc $(TOP) --top-module $(TOP) $(RTL_INCLUDE) $(VL_FLAGS) $(SRCS) -CFLAGS '$(CFLAGS)' -LDFLAGS '$(LDFLAGS)' -o ../$(PROJECT)
	make -j -C obj_dir -f V$(TOP).mk

clean:
	rm -rf $(PROJECT) obj_dir ../scope-defs.h $(RTL_DIR)/scope-defs.vh
