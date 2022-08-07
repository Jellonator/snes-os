# snes-os
SNES-OS/Snow-OS (working on title)

An operating system for the Super Nintendo Entertainment System/Super Famicom.

Created by Jocelyn "Jellonator" Beedie

Try it out here: https://jellonator.github.io/snes-os/

## Building

You must have Python 3 installed and in your PATH. Python is required for certain pre-processing steps, such as transforming image files into a format readable by the SNES.

You must also have the WLA-DX toolchain (https://github.com/vhelin/wla-dx) installed and in your PATH.

Once the prerequisites are installed, simply run `make` in the `snes-os` directory. This will build the operating system binary as `bin/snes-os.sfc`.

## Running

The operating system can be run in any SNES emulator; SNES9X, BSNES, and Mesen-S all work and have been tested.
