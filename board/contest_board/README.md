# contest_board: LicheeRV Nano (SG2002) OpenVela port

This directory contains the board adaptation for the SOPHGO SG2002
LicheeRV Nano board.

Mapped by the team manifest to:

```text
vendor/openvela/boards/contest2026_480_board
```

## Hardware

| Item | Value |
| --- | --- |
| SoC | SOPHGO SG2002 |
| CPU | T-Head C906 RISC-V, S-mode |
| DRAM | 256 MiB @ 0x80000000 |
| UART0 | 0x04140000, PLIC source 44, NuttX IRQ 69 |
| Console | 115200 8N1 |
| Boot | SD card: FSBL -> OpenSBI -> U-Boot -> NuttX |

## Build

From the openvela workspace root:

```bash
./build.sh vendor/openvela/boards/contest2026_480_board/configs/nsh -j8
```

The NuttX kernel configuration is in `configs/nsh/defconfig`.  The board
support reuses the in-tree `arch/risc-v/src/sg2000` SoC code.

Expected memory usage with the official prebuilt `riscv-none-elf`
toolchain:

```text
kflash: 188036 B / 2 MB (8.97%)
ksram:  48 KB / 2 MB (2.34%)
```

## Boot image

The kernel uses `CONFIG_BUILD_KERNEL=y`, so the bootable image is:

```text
Image-sg2002 = nuttx.bin + 64 KiB zero padding + initrd
boot.sd      = FIT(Image-sg2002 + sg2002-licheervnano_sd.dtb)
```

`scripts/make_boot_image.sh` assembles both files and copies the vendor
`fip.bin` (FSBL + OpenSBI + U-Boot) next to them:

```bash
cd <openvela-workspace>
board=/path/to/contest2026_480_OpenAT/board/contest_board
# Optional: MKIMAGE=/path/to/mkimage, INITRD=..., DTB=..., FIP=...
MKIMAGE=/path/to/mkimage \
  "$board/scripts/make_boot_image.sh" nuttx/nuttx.bin /tmp/boot_image
```

The script uses `prebuilt/initrd` and `prebuilt/sg2002-licheervnano_sd.dtb`
by default.  `mkimage` can come from `u-boot-tools` or from the LicheeRV
Nano SDK.  The prebuilt vendor `mkimage` also needs `dtc` in `PATH`.

Write the SD card:

```bash
sudo dd if=/tmp/boot_image/fip.bin of=/dev/sdX bs=4M conv=fsync
# Create a FAT32 partition (e.g. with gparted/mkfs.vfat) and copy:
#   /tmp/boot_image/boot.sd
```

The FAT32 partition root needs `fip.bin` and `boot.sd`; U-Boot then boots
the FIT configuration `config-sg2002_licheervnano_sd`.  Serial console is
UART0 at 115200 8N1.

## Prebuilt artifacts

`prebuilt/` contains the boot artifacts that are useful for a quick
reproduction:

| File | Description |
| --- | --- |
| `fip.bin` | Vendor SD boot chain: FSBL + OpenSBI + U-Boot |
| `initrd` | ROMFS user-space image (`/system/bin/init`, NSH, demos) |
| `sg2002-licheervnano_sd.dtb` | Device tree used by U-Boot and NuttX |

MD5:

```text
767738529ebe934892153ee7f89fe804  fip.bin
c713bcdc7e75e428e8441bd81c276b1e  initrd
5ff1717dd535030fa4891a354d886cfb  sg2002-licheervnano_sd.dtb
```

The `initrd` can be regenerated from the openvela workspace with the
standard NuttX apps flow (`nuttx make export` -> `apps/mkimport.sh` ->
`make import` -> `genromfs`); see the NuttX and openvela build
documentation.  Override `INITRD=` to use a freshly built image.

## NuttX libelf bug

OpenVela NuttX `dev-ai-contest-2026` currently has a bug in
`libs/libc/elf/elf_symbols.c::libelf_findsymbol()`: it does not skip
unnamed ELF symbols and dereferences a NULL `iobuffer` with `strcmp()`.
This board requires the fix (see team repo `patches/` or the upstream PR
<https://github.com/open-vela/nuttx/pull/381>).

## Toolchain workaround

The prebuilt openvela `riscv-none-elf` GCC 13.4.0 toolchain contains a
`libgcc.a` built with `-mcmodel=medlow`.  The `__clzdi2()` and `__ffsdi2()`
helpers in that archive reference the local `__clz_tab` symbol with
`R_RISCV_HI20`, which cannot be relocated when the MMU kernel is linked at
its high virtual address (`0xc0000000`).

`src/sg2002_libgcc_fix.c` provides medany-safe implementations of the four
`libgcc` helpers (`__clzsi2`, `__clzdi2`, `__ffssi2`, `__ffsdi2`) so the
linker does not pull the incompatible `_clzsi2.o` / `_ffssi2.o` objects out
of the prebuilt archive.
