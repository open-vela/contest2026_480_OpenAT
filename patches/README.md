# Public repository patches

These patches are required on the openvela common repositories for this
board.  They are submitted as separate PRs to `dev-ai-contest-2026` and are
kept here only as a reference for reviewers.

## 0001-libelf-skip-unnamed-symbols.patch

Applies to `open-vela/nuttx`:

```text
libs/libc/elf/elf_symbols.c
```

`libelf_findsymbol()` does not skip unnamed ELF symbols (for example the
mandatory null symbol at index zero).  It ends up calling `strcmp()` with
a NULL symbol name buffer, causing a load access fault during
`elf_loadbinary()`.

Upstream PR: <https://github.com/open-vela/nuttx/pull/381>

Apply with:

```bash
cd <openvela-workspace>/nuttx
git apply /path/to/patches/0001-libelf-skip-unnamed-symbols.patch
```
