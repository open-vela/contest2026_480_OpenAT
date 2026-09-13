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

## Boot

The resulting NuttX image is booted by U-Boot from a FIT image (`boot.sd`)
containing the NuttX Image and the LicheeRV Nano DTB.  See the team
repository `README.md` and `docs/` for the complete SD-card build flow.

## NuttX libelf bug

OpenVela NuttX `dev-ai-contest-2026` currently has a bug in
`libs/libc/elf/elf_symbols.c::libelf_findsymbol()`: it does not skip
unnamed ELF symbols and dereferences a NULL `iobuffer` with `strcmp()`.
This board requires the fix (see team repo `patches/` or the upstream PR).

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
