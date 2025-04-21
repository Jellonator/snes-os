## Challenges

65c816 has limited indirection and the SNES has no memory management unit.
Can not 'move' pages of memory outside of outright memcpying it, so allocating
extra memory is difficult.
This also means there is no easy way of implementing fork().
Only $2000 (8KB) bytes available to direct-page/stack

## Memory layout

Direct page is broken up into 256 blocks of 32B.
Spawned processes allocate blocks of direct page for their own use.
The D register is set to the top of this memory block, and the stack
register is set to the bottom of this memory block.

Currently, spawned processes allocate exactly 128B of direct page.

The first 8B of direct page are reserved for the operating system, and may be
modified when calling into OS functions.

Process `0` is the null process, and does not exist. Its direct page is
sometimes used by operating system functions while disabling interrupts.

Process `1` is the init process, which does nothing but loop reschedule. Its
direct page is used for the custom renderer's stack.

## Processes

A process table is used to store the following information about each process:
 * Process status (null, ready, suspended, etc.)
 * Process flags
 * Direct page index + count (which blocks are allocated)
 * Stack location (for resuming process)
 * Process name (bank + address)

When a process is created, it's data bank will be set to `$7F` by default.

When parameters are provided to a process, this data will be pushed to its
stack. When the process actually starts, the first argument can be accessed
via `$01,S`. For example, if the shell creates a new process, `argc` is
accessed as `$01,S`, and `argc` is accessed as `$03,S`.

## Rescheduling

When a process is rescheduled, the active registers must be stored so they can
later be retrieved. The following registers are stored on the stack:
 * Flags (F) [1B]
 * Program counter (PC, K) [3B]
 * C, X, Y [6B]
 * Data bank (B) [1B]
 * Direct page (D) [2B]

This totals 13B. At least this much stack space must always be available.

The stack register (S) is stored in the process table.

## Interrupts

Interrupts are used to drive multiprocessing/process switching.
When an interrupt or NMI is encountered, then the process will be switched to
another 'ready' process.

Note that only IRQ can be blocked by interrupt disable flag, NMI and BRK
still interrupt. NMI must be blocked by writing to NTIMEN.

## Rendering

One process at a time may take control of rendering.
A process can take control of rendering by calling `vSetRenderer(s24 addr)`.

Each NMI, the active renderer will be called into.

## Memory Allocation

All RAM in bank $7F is used for dynamic allocation. 
