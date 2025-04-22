true rendered area is about 256px×240px.
But, ntsc safe area is a bit more complicated.
For starters, danger zone reduces safe vertical area to 224px.
Furthermore, action safe area further reduces this to 240px×208px

We won't reduce this further (title safe area is 224x192).
Grab bars take up 8px on all sides.

Taskbar will take up bottom 16px.

Thus, the true largest window size (in terms of content) is 224px × 176px

Action safe area will be used as rendering area. The mouse can not leave this area.
Everything outside of action safe area will be rendered as black.

## Considered background modes

### mode 3

8bpp color mode; useful, but user has less control over exact color
Requires 38.5 KiB to fill full window.

BG1 can be used for window content
BG2 can be used for desktop environment UI

Uses too much VRAM for hi-res to be viable, and especially too much for hi-res + interlacing.

Similar to mentioned in 'mode 5', could cut down to 192x160 for hi-res mode, but non-square(ish)
pixels seems like a no-go to me.

### mode 5

4bpp color mode; less color depth per tile, but may have more control over exact colors.
Requires 19.25 KiB to fill full window.

BG1 can be used for window content
BG2 can be used for desktop environment UI

Hi-res is possible, instead using 38.5 KiB to fill full window.
Can't use in conjunction with interlacing, however.

If I want to use interlacing, then I need to reduce max window content size to 192x160
(208x176 effective size) => 60KiB

This means that 2KiB is reserved for nametables, leaving only 2KiB for sprites and OS tiles.
This means 64 4bpp tiles (sprites), or 128 2bpp tiles (OS).
Considering the minimalism of the desktop, this shouldn't be too bad.

The main limiting factor here will be vram upload rate, and RAM.
Can't use bank $7F, since it is reserved for allocated memory.
Can't use bank $7E, since at least $2000 is reserved for direct page.
So, tiles may need to be rendered on-demand during vblank, which is very time-inefficient.
Maybe we have $2000 in bank $7E reserved for to-upload tiles, render to these tiles during processing,
then upload during vblank?
We can upload up to 5K per frame during VBlank, though this can be extended to include the extra ignored lines from the NTSC safe area, and the cut area used to achieve full-res, to maybe reach the full 8KB/frame.
Regardless, it would take 8 frames to repaint the full screen this way, at least.