#!/bin/bash -ex
# Build kernel headers for the target EdgeRouter, then cross-compile amneziawg.ko.
# Mirrors the `headers` + `module` jobs of .github/workflows/build.yml so a local
# Docker build produces a byte-for-byte-equivalent module to the CI release.
#
# Required env: DEVICE FW CROSS KERNEL_GPL_URL MODULE_VERSION  (REPO defaults to /repo)
: "${DEVICE:?}"; : "${FW:?}"; : "${CROSS:?}"; : "${KERNEL_GPL_URL:?}"; : "${MODULE_VERSION:?}"
: "${REPO:=/repo}"

# Neutralise the DTC "multiple definition of yylloc" error that modern host GCC
# (-fno-common default) triggers when building the old kernel's host dtc tool.
fix_dtc() {
  find . -name "$1" -exec grep -l "YYLTYPE yylloc" {} \; 2>/dev/null | while read -r f; do
    sed -i 's/^[[:space:]]*YYLTYPE[[:space:]]\+yylloc[[:space:]]*;[[:space:]]*$/extern YYLTYPE yylloc;/' "$f"
  done
}

mkdir -p /headers /build && cd /build

# ---- kernel headers from the device's GPL source ----
curl -fsSL -o src.tar.bz2 "$KERNEL_GPL_URL"
tar -xf src.tar.bz2 --wildcards 'source/kernel_*' --strip-components 1
mv kernel_* kernel.tar.gz
tar -xf kernel.tar.gz --strip-components 1

fix_dtc dtc-lexer.l
fix_dtc 'dtc-lexer.lex.c*'
if [ "$FW" -ne 1 ]; then make ARCH=mips "ubnt_er_${DEVICE}_defconfig"; fi
if ! make -j"$(nproc)" ARCH=mips CROSS_COMPILE="$CROSS" prepare modules_prepare; then
  fix_dtc dtc-lexer.lex.c
  make -j"$(nproc)" ARCH=mips CROSS_COMPILE="$CROSS" prepare modules_prepare
fi
make -j"$(nproc)" ARCH=mips CROSS_COMPILE="$CROSS" modules
cp Module.symvers .config /headers
make mrproper
fix_dtc dtc-lexer.l
if ! make -j"$(nproc)" ARCH=mips O=/headers CROSS_COMPILE="$CROSS" prepare modules_prepare scripts; then
  fix_dtc dtc-lexer.lex.c
  make -j"$(nproc)" ARCH=mips O=/headers CROSS_COMPILE="$CROSS" prepare modules_prepare scripts
fi
rm -f /headers/source /headers/Makefile
# From Alpine (via ubuntu-zesty debian/rules.d): keep only what out-of-tree modules need
find . -path './include/*' -prune -o -path './scripts/*' -prune -o -type f \
  \( -name 'Makefile*' -o -name 'Kconfig*' -o -name 'Kbuild*' -o -name '*.sh' \
     -o -name '*.pl' -o -name '*.lds' -o -name 'Platform' \) -print | cpio -pdm /headers
cp -a scripts include /headers
find $(find arch -name include -type d -print) -type f | cpio -pdm /headers

# ---- AmneziaWG kernel module ----
cd /build
curl -fsSL -o m.tar.gz \
  "https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/tags/v${MODULE_VERSION}.tar.gz"
tar -xf m.tar.gz --one-top-level=module --strip-components=1
cd module
sed -i 's/ --dirty//g' src/Makefile
patch -p1 < "$REPO/siphash_no_fallthrough.patch" \
  || echo "siphash patch already applied upstream or not needed for module $MODULE_VERSION"
python3 "$REPO/fix_netlink_api.py"
cd src
# Force legacy-kernel mode (UBNT devices run 4.x, not 5.6+ with built-in WireGuard)
make V=1 ARCH=mips CROSS_COMPILE="$CROSS" KERNELDIR=/headers KERNELRELEASE=4.9.0 module
"${CROSS}strip" --strip-debug amneziawg.ko
mkdir -p /out && cp amneziawg.ko /out/
echo "built module vermagic: $(strings amneziawg.ko | grep -m1 'vermagic=')"
