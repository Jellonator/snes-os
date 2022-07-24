## Challenges

65c816 has limited indirection and no page tables;
can not 'move' pages of memory outside of
outright memcpying it, so allocating extra memory is difficult.
This also means there is no easy way of implementing fork()
Only $2000 (8KB) bytes available to direct-page/stack

## Memory layout

Can break up direct page into 256 blocks of 32B.
When process is created and requests space, stack is set to high bytes stack space,
and low bytes are used to store key process info

Alternatively: Store direct page in main RAM, and DMA it when needed.
This however would be slow.

## Processes

Process info:
 * A bank [db] (either $7E or $7F)
 * A page [db] + size [db]
 * A stack page [db] + size [db]
 * Register backups [A16, X16, Y16, S16, DB8, D16, PB8, PC16, P8] [15B]
 * A process ID [db]
 * A process state [db]
Process zeropage:
 * [dw] pointer, offset into process's bank
 * Rest of zeropage is available to programmer, as long as they are careful
 with their stack.

Process info is stored in table, with 24B per process (=6KB).
May store in individual tables
Bitmask to store page info, in 64B (512b) (256 pages * 2 RAM banks)
Bitmask to store stack/zp info, in 32B (256b)

This is all stored in the first few pages of the init process (24 + 1 + 1 pages)
Extra primary os data may be stored in more pages (likely just going to go with 32 pages)

Not that the first 32 pages (up to $2000) can not be mapped since they are
reserved for direct page data. Rest of pages (192 in $FE, and 256 in $FF)
will remain mappable.

## Interrupts

May use interrupts to drive multiprocessing/process switching.
Specifically, IRQ at specific intervals to switch several times per frame.
Note that only IRQ can be blocked by interrupt disable flag, VBlank and BRK
still interrupt.

## Rendering

We may also want (in the future) for certain programs to be able to 'listen'
for the VBlank interrupt so that it may render data. Will require some kind of
driver. For render code, two options:
 * Kernel has complete control, and data must be set to be uploaded during
 vblank from non-vblank code.
 * Kernel allows indirection to a single process's vblank handler:
    * 1: Trust that handler will not violate any assumptions, e.g. will not affect
    process table.
    * 2: Enforce that handler will not run while interrupts should be disabled.

## Shell

One built-in renderer: terminal emulator/shell.
Allows for typing and rendering text to screen via PPU.
Process will grab renderer access, to return it later (or when process exits).
The process with PPU access is stored as a process ID in memory.

When renderer is not in use, instead display printed output.