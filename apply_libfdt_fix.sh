#!/bin/bash
# Apply libfdt_env.h fix for older kernel builds

# Find kernel source directory (look for scripts/dtc directory)
KERNEL_DIR=""
for dir in . linux-* kernel-* source-*; do
    if [ -d "$dir/scripts/dtc" ]; then
        KERNEL_DIR="$dir"
        break
    fi
done

# If no kernel dir found, check if we're already in one
if [ -z "$KERNEL_DIR" ] && [ -d "scripts/dtc" ]; then
    KERNEL_DIR="."
fi

if [ -z "$KERNEL_DIR" ]; then
    echo "Error: Could not find kernel source directory with scripts/dtc"
    exit 1
fi

echo "Found kernel source in: $KERNEL_DIR"

# Create the libfdt_env.h file
cat > "$KERNEL_DIR/scripts/dtc/libfdt_env.h" << 'EOF'
#ifndef LIBFDT_ENV_H
#define LIBFDT_ENV_H
/*
 * libfdt - Flattened Device Tree manipulation
 * Copyright (C) 2006 David Gibson, IBM Corporation.
 * SPDX-License-Identifier: GPL-2.0+ OR BSD-2-Clause
 */

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#ifdef __CHECKER__
#define FDT_FORCE __attribute__((force))
#define FDT_BITWISE __attribute__((bitwise))
#else
#define FDT_FORCE
#define FDT_BITWISE
#endif

typedef uint16_t FDT_BITWISE fdt16_t;
typedef uint32_t FDT_BITWISE fdt32_t;
typedef uint64_t FDT_BITWISE fdt64_t;

#define fdt16_to_cpu(x) be16_to_cpu(x)
#define cpu_to_fdt16(x) cpu_to_be16(x)
#define fdt32_to_cpu(x) be32_to_cpu(x)
#define cpu_to_fdt32(x) cpu_to_be32(x)
#define fdt64_to_cpu(x) be64_to_cpu(x)
#define cpu_to_fdt64(x) cpu_to_be64(x)

#ifdef __LITTLE_ENDIAN
#define cpu_to_be16(x) ((uint16_t)((((uint16_t)(x) & 0x00ff) << 8) | \
                                   (((uint16_t)(x) & 0xff00) >> 8)))
#define cpu_to_be32(x) ((uint32_t)((((uint32_t)(x) & 0x000000ff) << 24) | \
                                   (((uint32_t)(x) & 0x0000ff00) << 8) | \
                                   (((uint32_t)(x) & 0x00ff0000) >> 8) | \
                                   (((uint32_t)(x) & 0xff000000) >> 24)))
#define cpu_to_be64(x) ((uint64_t)((((uint64_t)(x) & 0x00000000000000ffULL) << 56) | \
                                   (((uint64_t)(x) & 0x000000000000ff00ULL) << 40) | \
                                   (((uint64_t)(x) & 0x0000000000ff0000ULL) << 24) | \
                                   (((uint64_t)(x) & 0x00000000ff000000ULL) << 8) | \
                                   (((uint64_t)(x) & 0x000000ff00000000ULL) >> 8) | \
                                   (((uint64_t)(x) & 0x0000ff0000000000ULL) >> 24) | \
                                   (((uint64_t)(x) & 0x00ff000000000000ULL) >> 40) | \
                                   (((uint64_t)(x) & 0xff00000000000000ULL) >> 56)))
#else
#define cpu_to_be16(x) (x)
#define cpu_to_be32(x) (x)
#define cpu_to_be64(x) (x)
#endif

#define be16_to_cpu(x) cpu_to_be16(x)
#define be32_to_cpu(x) cpu_to_be32(x)
#define be64_to_cpu(x) cpu_to_be64(x)

#endif /* LIBFDT_ENV_H */
EOF

echo "Created $KERNEL_DIR/scripts/dtc/libfdt_env.h"

# Also apply the DTC multiple definition fix if dtc-lexer.l exists
if [ -f "$KERNEL_DIR/scripts/dtc/dtc-lexer.l" ]; then
    echo "Applying DTC multiple definition fix to dtc-lexer.l"
    sed -i '/^YYLTYPE yylloc;/d' "$KERNEL_DIR/scripts/dtc/dtc-lexer.l"
    echo "Applied DTC multiple definition fix"
fi

echo "libfdt_env.h fix applied successfully!"