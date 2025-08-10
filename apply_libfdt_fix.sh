#!/bin/bash
# Apply comprehensive DTC and libfdt_env.h fix for older kernel builds

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

# First, fix the yylloc declaration issue
find "$KERNEL_DIR" -name "dtc-lexer.l" -exec grep -l "YYLTYPE yylloc;" {} \; | while read -r file; do
    echo "Applying improved DTC fix to $file"
    sed -i 's/YYLTYPE yylloc;/extern YYLTYPE yylloc;/' "$file"
    # Also ensure YYLTYPE_IS_DECLARED is set  
    if ! grep -q "YYLTYPE_IS_DECLARED" "$file"; then
        sed -i '/extern YYLTYPE yylloc;/i #ifndef YYLTYPE_IS_DECLARED\n#define YYLTYPE_IS_DECLARED 1\n#endif' "$file"
    fi
done

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

# Apply fix to any generated files that might already exist
find "$KERNEL_DIR" -name "dtc-lexer.lex.c" -exec grep -l "YYLTYPE yylloc;" {} \; | while read -r file; do
    echo "Applying DTC fix to generated file $file"
    sed -i 's/YYLTYPE yylloc;/extern YYLTYPE yylloc;/' "$file"
done

echo "Comprehensive DTC and libfdt_env.h fix applied successfully!"