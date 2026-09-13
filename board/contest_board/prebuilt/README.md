# Prebuilt boot artifacts

These files make it possible to reproduce the LicheeRV Nano boot without a
full vendor SDK build.

| File | Source | MD5 |
| --- | --- | --- |
| `fip.bin` | LicheeRV-Nano-Build SDK image: FSBL + OpenSBI + U-Boot, for SG2002 + LicheeRV Nano SD board | `767738529ebe934892153ee7f89fe804` |
| `sg2002-licheervnano_sd.dtb` | Device tree compiled from the LicheeRV-Nano-Build SDK DTS | `5ff1717dd535030fa4891a354d886cfb` |
| `initrd` | ROMFS built from `openvela` `dev-ai-contest-2026` NuttX apps (`NuttXBootVol`) | `c713bcdc7e75e428e8441bd81c276b1e` |

`fip.bin` and the DTB are vendor boot artifacts for the SG2002 LicheeRV
Nano board.  The `initrd` is rebuilt from this contest branch and contains
the NSH shell and the demo applications selected by the board defconfig.

To rebuild the `initrd`, use the standard NuttX user-space flow:

```bash
cd <openvela-workspace>/nuttx
make export
cd ../apps
mkdir -p import
./tools/mkimport.sh -z -x ../nuttx/nuttx-export-0.0.0.tar.gz
make import -j8
cd ../nuttx
../prebuilts/build-tools/linux-x86_64/bin/genromfs \
  -f initrd -d ../apps/bin -V NuttXBootVol
```

Note: on the current `dev-ai-contest-2026` branch, the exported tree may
need a generated `apps/import/Make.defs` (the kernel `make export` puts
its Make.defs under `scripts/`).  See `board/contest_board/README.md`
for the image layout that consumes `initrd`.
