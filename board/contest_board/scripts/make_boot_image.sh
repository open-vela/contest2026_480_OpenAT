#!/usr/bin/env bash
############################################################################
# board/contest_board/scripts/make_boot_image.sh
#
# Assemble the LicheeRV Nano boot files from a NuttX kernel build:
#
#   Image-sg2002 = nuttx.bin + 64 KiB zero padding + initrd
#   boot.sd      = U-Boot FIT containing Image-sg2002 + board DTB
#
# Usage:
#   ./make_boot_image.sh <path/to/nuttx.bin> [output-directory]
#
# Environment overrides:
#   MKIMAGE  path to the U-Boot mkimage tool
#   INITRD   path to the user-space ROMFS initrd (default: ../prebuilt/initrd)
#   DTB      path to sg2002-licheervnano_sd.dtb (default: ../prebuilt/...)
#   FIP      path to the vendor fip.bin (default: ../prebuilt/fip.bin)
#
# SPDX-License-Identifier: Apache-2.0
############################################################################

set -euo pipefail

usage()
{
  echo "Usage: $0 <path/to/nuttx.bin> [output-directory]" >&2
  exit 1
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
fi

KERNEL_BIN=$(realpath "$1")
OUTDIR=$(realpath -m "${2:-$PWD/boot_image}")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BOARD_DIR=$(dirname "$SCRIPT_DIR")

INITRD=${INITRD:-"$BOARD_DIR/prebuilt/initrd"}
DTB=${DTB:-"$BOARD_DIR/prebuilt/sg2002-licheervnano_sd.dtb"}
FIP=${FIP:-"$BOARD_DIR/prebuilt/fip.bin"}

for f in "$KERNEL_BIN" "$INITRD" "$DTB" "$FIP" "$SCRIPT_DIR/boot.its"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: file not found: $f" >&2
    exit 1
  fi
done

# Locate mkimage if not supplied explicitly.

if [ -z "${MKIMAGE:-}" ]; then
  if command -v mkimage >/dev/null 2>&1; then
    MKIMAGE=$(command -v mkimage)
  else
    for candidate in \
      "$HOME/LicheeRV-Nano-Build/build/tools/common/prebuild/mkimage" \
      "$HOME/LicheeRV-Nano-Build/build/tools/common/mkimage" \
      "/usr/bin/mkimage"; do
      if [ -x "$candidate" ]; then
        MKIMAGE=$candidate
        break
      fi
    done
  fi
fi

if [ -z "${MKIMAGE:-}" ] || [ ! -x "$MKIMAGE" ]; then
  echo "ERROR: mkimage not found." >&2
  echo "       Install u-boot-tools (apt install u-boot-tools) or set MKIMAGE." >&2
  exit 1
fi

mkdir -p "$OUTDIR"

PAD=$(mktemp)
trap 'rm -f "$PAD"' EXIT

head -c 65536 /dev/zero > "$PAD"
cat "$KERNEL_BIN" "$PAD" "$INITRD" > "$OUTDIR/Image-sg2002"
cp "$DTB" "$OUTDIR/sg2002-licheervnano_sd.dtb"
cp "$SCRIPT_DIR/boot.its" "$OUTDIR/boot.its"

(
  cd "$OUTDIR"
  "$MKIMAGE" -f boot.its boot.sd >/dev/null
)

cp "$FIP" "$OUTDIR/fip.bin"

echo "Boot files written to $OUTDIR:"
ls -lh "$OUTDIR/Image-sg2002" "$OUTDIR/boot.sd" "$OUTDIR/fip.bin"
echo
echo "Next steps:"
echo "  1. Format an SD card with a FAT32 partition."
echo "  2. Copy fip.bin and boot.sd to the root of that partition."
echo "  3. Insert the card and power on the board."
