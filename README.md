# openvela on LicheeRV Nano (SG2002)

## 一、作品简介

本作品把 openvela / NuttX 适配到 SOPHGO **SG2002** 芯片的 **LicheeRV Nano**
开发板上。开发板通过 SD 卡依次加载 FSBL、OpenSBI、U-Boot，再由 U-Boot
引导 openvela NuttX 内核；系统以 RISC-V S-mode + MMU 运行，串口控制台
（UART0，115200 8N1）可启动到 NuttShell：

```text
Starting kernel ...
ABC
NuttShell (NSH)
nsh>
```

板级适配代码全部位于本仓 `board/contest_board/`，通过 manifest 的
`<linkfile>` 映射到 openvela 工作区的
`vendor/openvela/boards/contest2026_480_board`，对生产仓库零改动。

## 二、选题方向

**新硬件适配赛道**。

SG2002 / LicheeRV Nano 此前没有 openvela 官方适配。本作品完成了：

- 芯片级启动适配：S-mode、MMU、Sv39 页表、物理内存布局；
- 板级适配：defconfig、链接脚本、UART0 控制台、ROMFS/initrd 启动；
- 构建系统集成：基于 openvela 官方 `build.sh` 的板级 config 路径；
- 工具链适配：解决官方预编译 `riscv-none-elf` libgcc 在
  `0xc0000000` 高虚拟地址下的链接问题（见第六节）；
- 真机验证：FSBL → OpenSBI → U-Boot → NuttX → NSH 全链路启动成功。

## 三、目录结构

```text
board/contest_board/                 # SG2002 / LicheeRV Nano 板级适配
├── configs/nsh/defconfig            # 最小 NSH defconfig（UART0、MMU、kernel build）
├── include/board.h
├── include/board_memorymap.h        # 内存/UART/PLIC 地址
├── scripts/Make.defs                # 板级编译规则
├── scripts/ld.script                # kernel 链接脚本
├── src/sg2000_appinit.c             # 板级初始化
├── src/sg2002_libgcc_fix.c          # RISC-V libgcc 兼容函数
├── Kconfig
└── README.md                        # 板级适配说明与镜像制作步骤

app/hello_app/                       # 官方示例骨架（本作品未使用）
quickapp/hello_quickapp/             # 官方示例骨架（本作品未使用）
logs/                                # AI Coding 日志（按 GitHub 账号/日期归档）
```

## 四、运行方式

### 1. 获取 openvela 工作区

```bash
repo init -u https://github.com/open-vela/contest2026_480_OpenAT \
  -b dev-ai-contest-2026 -m contest2026_480_OpenAT.xml
repo sync -c -j8
```

同步后，本仓位于工作区根目录的 `contest2026_480_OpenAT/`，板级代码通过
linkfile 映射到 `vendor/openvela/boards/contest2026_480_board`。

### 2. 编译 NuttX 内核

在 openvela 工作区根目录执行：

```bash
./build.sh vendor/openvela/boards/contest2026_480_board/configs/nsh -j8
```

编译产物：

```text
nuttx/nuttx
nuttx/nuttx.bin
nuttx/nuttx.hex
nuttx/System.map
```

本次验证的内存占用：

```text
kflash: 188036 B / 2 MB (8.97%)
ksram:  48 KB / 2 MB (2.34%)
```

### 3. 制作可启动 SD 卡

openvela 使用 `CONFIG_BUILD_KERNEL=y` 的内核 + 用户态 initrd 方案，
NuttX 内核以 `Image-sg2002` 的形式打包：

```text
Image-sg2002 = nuttx.bin + 64 KiB 零填充 + initrd
```

`initrd` 由 NuttX `make export`、apps 的 `make import` 与 `genromfs`
生成；FIT 镜像 `boot.sd` 使用 U-Boot `mkimage` 打包 `Image-sg2002` 和
LicheeRV Nano 设备树。完整命令见
`board/contest_board/README.md` 的 “Boot image” 一节。把 `fip.bin`、
`boot.sd` 放入 SD 卡 FAT32 分区根目录即可由 U-Boot 自动启动。

### 4. 串口

```text
UART0: 0x04140000
PLIC source: 44
NuttX IRQ: 69
115200 8N1
```

## 五、AI Coding 使用说明

本作品的芯片移植、内存布局推导、链接脚本调试、构建错误排查以及真机启动
日志分析均借助 AI Coding 完成。AI 在以下环节提供了帮助：

- 从 SG2002 参考 SDK 中定位 UART/PLIC/DRAM 地址并整理 NuttX 配置；
- 分析 U-Boot `booti` 对 RISC-V Image 的要求，构造 FIT 与
  `Image-sg2002` 布局；
- 定位并修复 NuttX `libelf_findsymbol()` 空指针 panic；
- 定位官方 `riscv-none-elf` libgcc `R_RISCV_HI20` 链接错误并给出修复；
- 整理适配文档与复现步骤。

AI 对话日志见 `logs/yydawx/` 目录。

## 六、工具链说明

openvela 预编译的 `riscv-none-elf` GCC 13.4.0 中，`libgcc.a` 以
`-mcmodel=medlow` 编译。它的 `__clzdi2()` / `__ffsdi2()` 会通过
`R_RISCV_HI20` 引用本地 `__clz_tab`，在 kernel 链接到 `0xc0000000`
高虚拟地址时无法重定位：

```text
relocation truncated to fit: R_RISCV_HI20 against symbol `__clz_tab'
```

`board/contest_board/src/sg2002_libgcc_fix.c` 提供了 medany 安全的
`__clzsi2` / `__clzdi2` / `__ffssi2` / `__ffsdi2` 实现，避免链接器从
预编译 libgcc 中拉取不兼容的 `_clzsi2.o` / `_ffssi2.o`。

## 七、公共仓库修复

板子仍然需要 NuttX 公共仓库的一处修复才能运行 ELF 用户态程序：

- `libs/libc/elf/elf_symbols.c::libelf_findsymbol()` 未跳过 ELF 符号表
  中未命名的第 0 项，会以 NULL `iobuffer` 调用 `strcmp()`，导致内核在
  `elf_loadbinary()` 中 load access fault。

修复已提交到 NuttX `dev-ai-contest-2026` 分支：

- PR: <https://github.com/open-vela/nuttx/pull/381>

## 八、参考链接

- 大赛文档：<https://github.com/open-vela/docs/tree/dev-ai-contest-2026/zh-cn/contest_2026>
- 本仓板级说明：`board/contest_board/README.md`
- 本仓 PR：#1（初始板级适配）、#2（libgcc 修复）
