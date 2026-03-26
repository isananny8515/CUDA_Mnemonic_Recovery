.PHONY: help configure build release clean reconfigure

CMAKE ?= cmake
PRESET ?= linux-release
BUILD_PRESET ?= $(PRESET)
LINUX_BUILD_DIR ?= out/build/linux-release
CUDA_ARCHS ?=

ifdef CUDA_ARCHS
ifneq ($(strip $(CUDA_ARCHS)),)
CONFIGURE_ARCH_ARG := -D CMAKE_CUDA_ARCHITECTURES=$(CUDA_ARCHS)
endif
endif

help:
	@echo "Targets:"
	@echo "  make configure            Configure the Linux/WSL build tree"
	@echo "  make build                Build the Linux/WSL preset"
	@echo "  make release              Configure and build in one go"
	@echo "  make clean                Remove the Linux/WSL build tree"
	@echo "  make reconfigure          Recreate the Linux/WSL build tree"
	@echo ""
	@echo "Variables:"
	@echo "  PRESET=linux-release      CMake configure preset"
	@echo "  BUILD_PRESET=linux-release CMake build preset"
	@echo "  CUDA_ARCHS=89             Override CUDA architectures for this run"

configure:
	$(CMAKE) --preset $(PRESET) $(CONFIGURE_ARCH_ARG)

build:
	$(CMAKE) --build --preset $(BUILD_PRESET)

release: configure build

clean:
	rm -rf $(LINUX_BUILD_DIR)

reconfigure: clean configure
