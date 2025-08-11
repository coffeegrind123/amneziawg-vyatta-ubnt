# AmnesiaWG Module Build System Analysis

## Overview
The AmnesiaWG module build system for VyattaOS/EdgeMax devices is implemented through GitHub Actions workflows that download external source code and build kernel modules for various UBNT device architectures.

## Key Build Process Flow

### 1. Module Source Preparation (`module-prepare` job)
- Downloads AmnesiaWG kernel module source from: `https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/tags/v$MODULE_VERSION.tar.gz`
- Extracts to `module/` directory with `--one-top-level=module --strip-components=1`
- Applies patches including `siphash_no_fallthrough.patch`
- Modifies `src/Makefile` to remove `--dirty` flag

### 2. Headers Preparation (`headers` job)
- Downloads kernel sources for specific UBNT devices from URLs in `ci/ubnt-source.json`
- Builds kernel headers for cross-compilation
- Applies comprehensive DTC (Device Tree Compiler) fixes for `yylloc` multiple definition issues
- Creates `/headers` directory with prepared kernel build environment

### 3. Module Building (`module` job)
- Restores module source and headers from previous jobs
- **Critical build command**: 
  ```bash
  cd module/src
  make -j$(nproc) ARCH=mips CROSS_COMPILE=${{ matrix.toolchain }} KERNELDIR=$GITHUB_WORKSPACE/headers module
  ```
- Strips debug symbols from resulting `wireguard.ko`

## The Missing `module/src/generated/Makefile` Issue

### Root Cause Analysis
The error "module/src/generated/Makefile: No such file or directory" suggests that:

1. **The `module/` directory structure is not present locally** - it's only created during CI/CD pipeline execution
2. **The `generated/` directory is expected to be created during the build process** - likely by the upstream AmnesiaWG module build system
3. **Local builds are not supported without proper setup** - the system expects the full CI environment

### Expected Directory Structure (during build)
```
module/
├── src/
│   ├── Makefile                    # Main module Makefile
│   ├── generated/                  # Auto-generated during build
│   │   └── Makefile               # Generated Makefile (missing)
│   ├── wireguard.ko               # Built module (output)
│   └── [other source files]
```

### What Should Generate the Files
1. **Module source download**: The `module-prepare` job downloads and extracts the AmnesiaWG kernel module source
2. **Makefile modifications**: The build process modifies the original Makefiles
3. **Kernel build system**: The Linux kernel build system (via `make module`) should create generated files

## Build Dependencies
- Cross-compilation toolchains (mips64-octeon-linux-, mipsel-mtk-linux-)
- Kernel headers for target devices
- Docker build environment with proper packages
- AmnesiaWG source code (not included in this repository)

## Architecture Support
- MIPS64 Octeon: e100, e200, e300, e1000, ugw3, ugw4, ugwxg
- MIPSEL MTK: e50
- Version variants: v1 and v2 firmware

## Current Module Version
- MODULE_VERSION: "1.0.20241112"  
- TOOLS_VERSION: "1.0.20250706"

## Key Issue: Missing module/src/generated/Makefile

### Problem Analysis
The error "module/src/generated/Makefile: No such file or directory" occurs because:

1. **Missing Source Code**: The AmnesiaWG module source is NOT included in this repository
2. **CI-Only Build Process**: Module building only works in GitHub Actions CI environment
3. **External Dependencies**: Requires downloaded source from `https://github.com/amnezia-vpn/amneziawg-linux-kernel-module`
4. **Generated Directory**: The `generated/` directory is created by the Linux kernel build system during module compilation

### Root Cause: Linux Kernel Build System (kbuild) Requirements

The error `scripts/Makefile.build:44: /__w/amneziawg-vyatta-ubnt/amneziawg-vyatta-ubnt/module/src/generated/Makefile: No such file or directory` indicates a failure in the Linux kernel build system (kbuild) that manages out-of-tree module compilation.

#### What Should Create the Generated Directory

1. **Kernel Preparation Process**: The `generated/` directory and its Makefile are created during kernel preparation steps:
   - `make oldconfig` - configures the kernel based on existing .config
   - `make prepare` - prepares kernel headers and generated files
   - `make scripts` - builds necessary build scripts

2. **kbuild System**: The Linux kernel build system automatically creates:
   - `include/generated/autoconf.h` - kernel configuration header
   - `include/config/auto.conf` - configuration data for make
   - `scripts/` directory with build tools like `fixdep`, `mkmakefile`
   - `generated/` directory with build-specific files

#### KERNELDIR Path Requirements

The `KERNELDIR=$GITHUB_WORKSPACE/headers` variable must point to a **properly prepared kernel build directory** containing:

- Configured kernel source (`.config` file)
- Prepared kernel headers (`include/generated/` directory)
- Built kernel scripts (`scripts/` directory)  
- Module symbol information (`Module.symvers`)
- Prepared build infrastructure

#### Cross-Compilation Specifics for MIPS

For MIPS cross-compilation (`ARCH=mips CROSS_COMPILE=mips64-octeon-linux-`):

1. **Toolchain Dependency**: The cross-compilation toolchain must be properly installed
2. **Architecture-Specific Preparation**: The kernel headers must be prepared for the target MIPS architecture
3. **Scripts Compatibility**: Build scripts must be compiled for the host architecture (not target)

### Solution Requirements

To fix the missing Makefile issue, you need to:

1. **Download Module Source**: 
   ```bash
   curl -L -o amneziawg-linux-kernel-module-1.0.20241112.tar.gz https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/tags/v1.0.20241112.tar.gz
   tar -xf amneziawg-linux-kernel-module-1.0.20241112.tar.gz --one-top-level=module --strip-components=1
   ```

2. **Apply Required Patches**:
   ```bash
   cd module
   sed -i 's/ --dirty//g' src/Makefile
   patch -p1 < ../siphash_no_fallthrough.patch
   ```

3. **Prepare Kernel Build Directory** (most critical step):
   ```bash
   # Download and extract kernel source
   # Configure for target device
   make ARCH=mips CROSS_COMPILE=mips64-octeon-linux- oldconfig
   make ARCH=mips CROSS_COMPILE=mips64-octeon-linux- prepare
   make ARCH=mips CROSS_COMPILE=mips64-octeon-linux- scripts
   ```

4. **Build with Properly Prepared Headers**:
   ```bash
   cd module/src
   make ARCH=mips CROSS_COMPILE=mips64-octeon-linux- KERNELDIR=/path/to/prepared/headers module
   ```

### Why the Error Occurs in CI Environment

The GitHub Actions workflow handles this correctly by:

1. **Headers Job** (lines 54-117): Downloads kernel source, applies DTC fixes, runs full kernel preparation:
   ```yaml
   make -j$(nproc) ARCH=mips CROSS_COMPILE=$CROSS prepare modules_prepare
   make -j$(nproc) ARCH=mips O=/headers CROSS_COMPILE=$CROSS prepare modules_prepare scripts
   ```

2. **Module Job** (lines 138-189): Uses the prepared headers directory created by the headers job

### Local Development Not Supported

This repository is designed for CI/CD builds only. Local development requires:
- Setting up the full build environment manually
- Downloading external dependencies (module source + kernel source)
- Cross-compilation toolchains for MIPS architectures
- Device-specific kernel source and proper preparation
- Applying DTC (Device Tree Compiler) fixes for `yylloc` multiple definition issues

The `modules/` directory in this repo is empty and serves as an output directory for CI builds.