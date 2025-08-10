#!/bin/bash
# Simple script to create libfdt_env.h for DTC build

if [ ! -d scripts/dtc ]; then
    echo "Error: scripts/dtc directory not found"
    exit 1
fi

echo "Creating libfdt_env.h..."

cat > scripts/dtc/libfdt_env.h << 'LIBFDT_EOF'
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

#define be16_to_cpu(x) cpu_to_be16(x)
#define be32_to_cpu(x) cpu_to_be32(x)
#define be64_to_cpu(x) cpu_to_be64(x)

#ifdef __LITTLE_ENDIAN
static inline uint16_t cpu_to_be16(uint16_t x) { return ((x & 0x00ff) << 8) | ((x & 0xff00) >> 8); }
static inline uint32_t cpu_to_be32(uint32_t x) { return ((x & 0x000000ff) << 24) | ((x & 0x0000ff00) << 8) | ((x & 0x00ff0000) >> 8) | ((x & 0xff000000) >> 24); }
static inline uint64_t cpu_to_be64(uint64_t x) { return ((x & 0x00000000000000ffULL) << 56) | ((x & 0x000000000000ff00ULL) << 40) | ((x & 0x0000000000ff0000ULL) << 24) | ((x & 0x00000000ff000000ULL) << 8) | ((x & 0x000000ff00000000ULL) >> 8) | ((x & 0x0000ff0000000000ULL) >> 24) | ((x & 0x00ff000000000000ULL) >> 40) | ((x & 0xff00000000000000ULL) >> 56); }
#else
#define cpu_to_be16(x) (x)
#define cpu_to_be32(x) (x)
#define cpu_to_be64(x) (x)
#endif

#endif /* LIBFDT_ENV_H */
LIBFDT_EOF

echo "Created scripts/dtc/libfdt_env.h successfully"