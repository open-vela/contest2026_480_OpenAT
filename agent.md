# agent.md — OpenVela SG2002 / LicheeRV Nano 适配约束

本文件定义 AI Agent 在本项目中必须遵守的约束。所有 Agent 操作前必须先读本文件。
如本文件与用户的实时指令冲突，以用户的实时指令为准；并在执行后回头更新本文件。

## 1. 项目目标与边界

目标：把 openvela / NuttX 适配到 SOPHGO SG2002（LicheeRV Nano），完成
BSP、UART 控制台、内核构建、真机启动到 `nsh>`，并按大赛要求提交到团队仓。

固定路径：

```text
官方工作区: /home/yyda/workspace/openvela-2002/contest_workspace
团队仓:     <官方工作区>/contest2026_480_OpenAT
板级映射:   <官方工作区>/vendor/openvela/boards/contest2026_480_board
              -> contest2026_480_OpenAT/board/contest_board
```

允许 Agent 直接修改的路径（团队仓内）：

```text
board/      # 板级适配：defconfig、链接脚本、板级初始化、工具链 workaround
app/        # 可选应用代码
quickapp/   # 可选快应用骨架
docs/       # 文档
patches/    # 公共仓库补丁参考
logs/       # AI Coding 日志（按 GitHub 账号/日期归档）
README.md
agent.md
```

禁止直接修改公共仓库源码：

```text
nuttx/  apps/  frameworks/  packages/  vendor/  external/  build/  prebuilts/ ...
```

需要修改公共仓库时：fork 对应仓库 → 创建分支 → PR 到 `dev-ai-contest-2026`
→ 等 review / CI；不得直接 push 到 `open-vela/*`。

## 2. 串口与真机操作约束（最高优先级）

1. **所有内核、U-Boot、NuttX 串口命令必须由用户在 `picocom` 中执行。**
   Agent 不得占用、打开或自动读写 `/dev/ttyUSB0`，不得用脚本自动发送
   U-Boot / NuttX 命令。
2. Agent 只能提供：命令、执行顺序、预期输出、判断标准、失败后的下一步。
   用户执行后把串口输出拷贝给 Agent，Agent 基于用户反馈做判断。
3. 如果 Agent 写了串口自动化脚本，只能作为“供用户选择执行的命令序列”交付，
   不得由 Agent 自行运行。
4. 任何需要上电、断电、按 RESET、插拔 SD 卡、插拔 USB 串口的动作，都由用户执行。
5. Agent 在给出真机命令前，必须先把命令和预期结果写清楚，等用户确认后再执行。

## 3. 内核更新与烧录约束

### 3.1 内核侧变更：必须重新烧录 / 重新启动

以下变更属于“内核更新”，**必须重新烧录并用新内核启动**，不能只改文件系统：

- `nuttx/` 源码、Kconfig、defconfig、链接脚本、启动代码；
- `board/contest_board/` 中参与内核编译的代码（board init、kernel C 文件、
  工具链兼容代码、内存布局、UART/PLIC 等内核态驱动）；
- 内核编译参数、cflags、ldflags、`CONFIG_BUILD_KERNEL` 等；
- `nuttx.bin`、`Image-sg2002`、含内核的 `boot.sd` FIT；
- `fip.bin`（FSBL + OpenSBI + U-Boot 启动链）。

要求：

1. 重新编译内核并记录 `nuttx.bin` / `Image-sg2002` / `boot.sd` 的 MD5 与
   git commit。
2. 烧录/替换启动介质，然后由用户冷启动或按 RESET。
3. 必须回读串口完整启动日志；确认出现 `Starting kernel ...`、`NuttShell`
   和 `nsh>`。出现 panic 必须把完整日志交给 Agent 分析，不得跳过。

### 3.2 文件系统侧变更：可不烧录全量 img

以下变更属于“文件系统更新”，**可以只修改文件系统，不必重烧全量 SD 镜像**：

- `initrd` / ROMFS 内容；
- `/system/bin`、`/system/etc` 下的用户态程序、脚本、配置；
- 应用 Demo、NSH 启动脚本、资源文件等只运行在用户态的内容。

推荐方式（命令由 Agent 给出，用户在 picocom/U-Boot 或宿主机执行）：

1. 只重新生成 `initrd`，再按需替换启动介质上的 `boot.sd` 或文件系统分区；
2. 或在 U-Boot 下用 `loadx/loady`/文件系统命令更新对应文件；
3. 或直接替换挂载点下的文件后重启。

注意：如果文件系统更新仍然需要替换 FIT `boot.sd`（其中包含内核），
则应同时视为内核更新，必须确认 `boot.sd` 里的内核版本与预期一致，
并在验证时回读启动日志中的内核版本号/编译时间。

### 3.3 烧录前后检查清单

每次烧录前：

- [ ] 确认板子已断电；
- [ ] 记录本次要写入的文件的 MD5；
- [ ] 备份当前可启动镜像（至少保留上一版 `boot.sd` / `fip.bin`）。

每次烧录后：

- [ ] 用户执行冷启动/复位；
- [ ] 用户提供完整串口日志；
- [ ] Agent 检查启动链版本、是否进入 NSH、是否有 panic；
- [ ] 失败时保留现场，先分析再决定回退。

## 4. 构建约束

统一从官方工作区根目录执行：

```bash
./build.sh vendor/openvela/boards/contest2026_480_board/configs/nsh -j8
```

干净重建：

```bash
./build.sh vendor/openvela/boards/contest2026_480_board/configs/nsh distclean
./build.sh vendor/openvela/boards/contest2026_480_board/configs/nsh -j8
```

构建成功判据：

- 退出码为 0；
- 生成 `nuttx/nuttx`、`nuttx/nuttx.bin`；
- 内存占用正常（参考当前约 `kflash 188 KB`、`ksram 48 KB`）；
- 不出现 `relocation truncated`、`Error:`、`undefined reference`。

制作启动镜像：

```bash
MKIMAGE=<mkimage 路径> \
  contest2026_480_OpenAT/board/contest_board/scripts/make_boot_image.sh \
  nuttx/nuttx.bin /tmp/boot_image
```

`mkimage` 缺省使用仓库内脚本的查找逻辑；LicheeRV Nano SDK 的
`mkimage` 还需要 `dtc` 在 PATH 中。

## 5. 公共仓库修复约束

NuttX `dev-ai-contest-2026` 需要 libelf 修复才能在 kernel build 下调起
用户态 ELF 程序；补丁见：

```text
patches/0001-libelf-skip-unnamed-symbols.patch
```

上游 PR：<https://github.com/open-vela/nuttx/pull/381>

在该 PR 合入前，本地工作区必须 `git apply` 此补丁后再编译内核；否则内核会在
`AppBringUp` / `elf_loadbinary()` 处发生 load access fault。

工具链兼容修复（`riscv-none-elf` libgcc medlow）位于：

```text
board/contest_board/src/sg2002_libgcc_fix.c
```

不得删除，否则官方预编译工具链链接会失败。

## 6. 提交与日志约束

- 提交走 fork + PR + 自行 review 合入，PR 目标分支 `dev-ai-contest-2026`；
- 一个 commit 只做一类事情，commit message 用英文祈使句，必要时加
  `Signed-off-by: yyda <snowmantin@foxmail.com>`；
- 不提交编译产物（`*.o`、`*.a`、`nuttx`、`nuttx.bin`、`Image-*`、`out/` 等），
  仓库内 `prebuilt/` 下的可启动镜像除外；
- AI Coding 日志统一导出到 `logs/yydawx/<日期>/`，不得加入 `.gitignore`；
- 不提交 token、密码、私钥、个人路径以外的敏感信息；
- 仓库提交前先 `git status`、`git diff --check`。

## 7. 硬件参数（固定，不要随意改）

```text
SoC:          SOPHGO SG2002
CPU:          T-Head C906 RISC-V, S-mode + MMU (Sv39)
DRAM:         256 MiB @ 0x80000000
Kernel VMA:   0xc0000000 (text), 0xc0100000 (data)
UART0:        0x04140000, PLIC source 44, NuttX IRQ 69
Console:      115200 8N1
Boot chain:   FSBL -> OpenSBI -> U-Boot -> NuttX
```

## 8. 禁止事项汇总

- ❌ Agent 自行操作 `/dev/ttyUSB0` 或自动执行 U-Boot/NuttX 命令；
- ❌ 未经用户确认执行烧录、格式化、挂载、断电/复位；
- ❌ 直接修改或 push `open-vela/*` 公共仓库；
- ❌ 在团队仓根目录和板级目录提交编译中间产物；
- ❌ 使用 `--force`/`--force-with-lease` 推公共分支（仅自己的 fork 可谨慎使用）；
- ❌ 在没有串口日志证据的情况下声称“已启动成功”。
