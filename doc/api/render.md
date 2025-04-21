# Rendering API

## vCopyPalette16

`vCopyPalette([s8]int palette_index, [s24]void* data)`

Copy 16 bytes from `data` into CGRAM, starting at `palette_index`.

This function should only be called during blanking periods.

## vCopyPalette4

`vCopyPalette([s8]int palette_index, [s24]void* data)`

Copy 4 bytes from `data` into CGRAM, starting at `palette_index`.

This function should only be called during blanking periods.

## vCopyMem

`vCopyMem([s16]int address, [s16]int size, [s24]void* data)`

Copy `size` bytes from `data` into VRAM at address `address`.

This function should only be called during blanking periods.

## vClearMem

`vClearMem([s16]int address, [s16]int size)`

Clear `size` bytes in VRAM, starting from `address`.

This function should only be called during blanking periods.

## vSetRenderer

`vSetRenderer([s24]void* function)`

Set the rendering function to the given function pointer.