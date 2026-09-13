/****************************************************************************
 * Contest 2026 team 480 board: LicheeRV Nano / SG2002
 *
 * The openvela prebuilt riscv-none-elf GCC 13.4.0 libgcc was built with
 * -mcmodel=medlow.  Its _clzsi2.o and _ffssi2.o use R_RISCV_HI20
 * relocations against the local __clz_tab symbol, which cannot be resolved
 * when the kernel is linked at its high virtual address (0xc0000000).
 *
 * Providing the four libgcc helpers here prevents the linker from pulling
 * those two objects out of libgcc.a.  The implementations deliberately do
 * not use compiler builtins so they cannot recurse back into libgcc.
 *
 ****************************************************************************/

/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <nuttx/config.h>

#ifdef CONFIG_ARCH_CHIP_SG2000

/****************************************************************************
 * Public Function Prototypes
 ****************************************************************************/

int __clzsi2(unsigned int x);
int __clzdi2(unsigned long long x);
int __ffssi2(unsigned int x);
int __ffsdi2(unsigned long long x);

/****************************************************************************
 * Public Functions
 ****************************************************************************/

int __clzsi2(unsigned int x)
{
  int n = 0;

  if (x == 0)
    {
      return 32;
    }

  if ((x & 0xffff0000u) == 0)
    {
      n += 16;
      x <<= 16;
    }

  if ((x & 0xff000000u) == 0)
    {
      n += 8;
      x <<= 8;
    }

  if ((x & 0xf0000000u) == 0)
    {
      n += 4;
      x <<= 4;
    }

  if ((x & 0xc0000000u) == 0)
    {
      n += 2;
      x <<= 2;
    }

  if ((x & 0x80000000u) == 0)
    {
      n += 1;
    }

  return n;
}

int __clzdi2(unsigned long long x)
{
  int n = 0;

  if (x == 0)
    {
      return 64;
    }

  if ((x & 0xffffffff00000000ull) == 0)
    {
      n += 32;
      x <<= 32;
    }

  if ((x & 0xffff000000000000ull) == 0)
    {
      n += 16;
      x <<= 16;
    }

  if ((x & 0xff00000000000000ull) == 0)
    {
      n += 8;
      x <<= 8;
    }

  if ((x & 0xf000000000000000ull) == 0)
    {
      n += 4;
      x <<= 4;
    }

  if ((x & 0xc000000000000000ull) == 0)
    {
      n += 2;
      x <<= 2;
    }

  if ((x & 0x8000000000000000ull) == 0)
    {
      n += 1;
    }

  return n;
}

int __ffssi2(unsigned int x)
{
  int n = 0;

  if (x == 0)
    {
      return 0;
    }

  while ((x & 1u) == 0)
    {
      n++;
      x >>= 1;
    }

  return n + 1;
}

int __ffsdi2(unsigned long long x)
{
  int n = 0;

  if (x == 0)
    {
      return 0;
    }

  while ((x & 1ull) == 0)
    {
      n++;
      x >>= 1;
    }

  return n + 1;
}

#endif /* CONFIG_ARCH_CHIP_SG2000 */
