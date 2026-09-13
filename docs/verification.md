# 真机验证记录

## 测试环境

| 项目 | 值 |
| --- | --- |
| 开发板 | SOPHGO LicheeRV Nano (SG2002) |
| 启动链 | FSBL -> OpenSBI -> U-Boot -> NuttX |
| 工作区 | openvela `dev-ai-contest-2026` |
| 内核提交 | 团队仓 PR #3 对应工作区 + 本地 NuttX libelf 修复 |
| 内核工具链 | openvela 预编译 `riscv-none-elf` GCC 13.4.0 |
| 内核编译时间 | 2026-09-13 22:39 |
| `boot.sd` MD5 | `c428c6b8a6162b463ad90569ab089950` |
| `Image-sg2002` MD5 | `f8c19f5e297e94e885509ffc21448283` |
| 串口 | UART0, 115200 8N1 |

本次验证使用的 `boot.sd` 包含：

1. `board/contest_board/src/sg2002_libgcc_fix.c` 工具链兼容修复；
2. NuttX 公共仓库 libelf 修复（PR #381，尚未合入时以
   `patches/0001-libelf-skip-unnamed-symbols.patch` 形式应用）；
3. `prebuilt/initrd` 中的用户态 ROMFS。

## 修复前的 panic

未应用 libelf 修复时，U-Boot 已经成功加载并跳转到 NuttX，但内核在
`AppBringUp` 加载用户态 ELF 时触发了 load access fault：

```text
Starting kernel ...

ABC
riscv_exception: EXCEPTION: Load access fault. MCAUSE: 0000000000000005
EPC: 00000000802201d8, MTVAL: 0000000000000000
riscv_exception: PANIC!!! Exception = 0000000000000005
dump_assert_info: Assertion failed panic: at file: common/riscv_exception.c:131
task: AppBringUp process: Kernel 0x802014d8
```

## 修复后的完整启动日志

```text
Boot from SD dev 0 ...
switch to partitions #0, OK
mmc0 is current device
3967132 bytes read in 351 ms (10.8 MiB/s)
## Loading kernel from FIT Image at 81800000 ...
   Using 'config-sg2002_licheervnano_sd' configuration
   Trying 'kernel-1' kernel subimage
     Description:  NuttX/OpenVela kernel
     Type:         Kernel Image
     Compression:  uncompressed
     Data Start:   0x818000e4
     Data Size:    3943057 Bytes = 3.8 MiB
     Architecture: RISC-V
     OS:           Linux
     Load Address: 0x80200000
     Entry Point:  0x80200000
     Hash algo:    crc32
     Hash value:   192cf999
   Verifying Hash Integrity ... crc32+ OK
## Loading fdt from FIT Image at 81800000 ...
   Using 'config-sg2002_licheervnano_sd' configuration
   Trying 'fdt-sg2002_licheervnano_sd' fdt subimage
     Description:  LicheeRV Nano Device Tree (SG2002)
     Type:         Flat Device Tree
     Compression:  uncompressed
     Data Start:   0x81bc2c84
     Data Size:    22206 Bytes = 21.7 KiB
     Architecture: RISC-V
     Hash algo:    crc32
     Hash value:   a0e2b0d3
   Verifying Hash Integrity ... crc32+ OK
   Booting using the fdt blob at 0x81bc2c84
   Loading Kernel Image
   Decompressing 3943057 bytes used 5ms
   Loading Device Tree to 00000000880e2000, end 00000000880ea6bd ... OK

Starting kernel ...

ABC
NuttShell (NSH)
nsh>
```

结论：openvela NuttX 已在 SG2002 / LicheeRV Nano 上完成从 SD 卡启动链
到 NSH 的完整验证。

## 复现命令

宿主机侧编译与打包：

```bash
cd <openvela-workspace>
./build.sh vendor/openvela/boards/contest2026_480_board/configs/nsh -j8

MKIMAGE=<mkimage 路径> \
  contest2026_480_OpenAT/board/contest_board/scripts/make_boot_image.sh \
  nuttx/nuttx.bin /tmp/boot_image
```

将 `/tmp/boot_image/fip.bin`（首次烧录）和 `boot.sd` 写入 SD 卡 FAT32
分区，插入开发板后串口 115200 8N1 观察启动。
