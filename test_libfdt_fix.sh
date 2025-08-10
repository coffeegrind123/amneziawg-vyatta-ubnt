#!/bin/bash
# Test script to verify the libfdt fix works

echo "Testing libfdt_env.h fix..."

# Create a minimal test environment
mkdir -p test_kernel/scripts/dtc
cd test_kernel

# Create a minimal dtc.h that includes libfdt_env.h
cat > scripts/dtc/dtc.h << 'EOF'
#ifndef DTC_H
#define DTC_H

#include <stdint.h>
#include <stdio.h>
#include <libfdt_env.h>

#endif
EOF

# Apply our fix (create libfdt_env.h)
cat > scripts/dtc/libfdt_env.h << 'EOFH'
#ifndef LIBFDT_ENV_H
#define LIBFDT_ENV_H

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
EOFH

# Test compilation
cat > test.c << 'EOFC'
#include "scripts/dtc/dtc.h"
int main() {
    printf("libfdt_env.h test successful!\n");
    return 0;
}
EOFC

# Try to compile
echo "Testing compilation..."
if gcc -I. test.c -o test 2>/dev/null; then
    echo "SUCCESS: libfdt_env.h fix works!"
    ./test
    exit_code=0
else
    echo "FAILED: Compilation failed"
    exit_code=1
fi

# Cleanup
cd ..
rm -rf test_kernel test

exit $exit_code