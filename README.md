# SNOW OS

SNOW (Super Nes Open Workspace) is an operating system for the Super Nintendo Entertainment System/Super Famicom.

This operating system is currently experimental, and is subject to change. Updates between versions may break saved filesystems. Don't save anything to the internal filesystem that you would be sad to have corrupted.

## Running the operating system

### Building the ROM

You must have Python 3 installed and in your PATH. Python is required for certain pre-processing steps, such as transforming image files into a format readable by the SNES.

You must also have the WLA-DX toolchain (https://github.com/vhelin/wla-dx) installed and in your PATH.

Once the prerequisites are installed, simply run `make` in the `snes-os` directory. This will build the operating system binary as `bin/snes-os.sfc`.

### Running the ROM on an emulator

The operating system can be run in any SNES emulator; SNES9X, BSNES, and Mesen-S all work and have been tested.

### Running the ROM on a cartridge

This operating system has not yet been tested on cartridges. If you attempt to run this operating system on a cartridge, it is advised to use a cartridge with at least 128KiB of SRAM.
No expansion chips are required.

## Using SNOW OS

### Shell

SNOW uses a simple shell, which executes commands with a list of arguments.

The SNES controller is used to type out commands. The D-Pad is used to select a character. The 'Select' button is used to swap character sets (lowercase, uppercase, and symbols). The 'A' button is used to input a character. The 'B' button is used to delete a character. The 'Y' button is used to insert a space. The 'Start' button is used to enter your command.

A list of available commands are listed below:

#### help

`help`

Currently, this command lists all available commands.

#### cat

`cat {filename}`

Currently, this command reads the contents of a file, and outputs it into the shell.

Since folders can be read as files you can use `cat {folder path}` to list all files in that directory.

#### cp

`cp {source} {dest}`

Copy a file from `source` to `dest`.

#### echo

`echo [string...] [-o filename]`

Print a list of given strings to the shell.

Optionally, if `-o` is provided as an argument, it will write the list of strings to a file instead.

#### meminfo

`meminfo`

List all allocated blocks of memory and their owning process's PID.

#### mkdir

`mkdir {path}`

Create a directory at `path`.

#### ps

`ps`

This command lists all active processes in a table. The `PI` column is the process ID, The `S` column is the process state, and the `NAME` column is the process name.

Process states:

State | Name | Description
--|--|--
`R` | Ready | Process is active
`S` | Suspended | Process is suspended, and will not run until awoken
`I` | wait for Interrupt | Process will activate when the next frame begins
`W` | Wait | Process is waiting on a semaphore

#### rm

`rm {path}`

Delete the file at `path`.

#### touch

`touch {path}`

Create a file at `path`.

### Filesystem

SNOW features a simple filesystem, with a few predefined root directories.

#### File names

File names begin with a '/', with path pieces separated by '/'. For example, '/tmp/foo/bar' is a valid filename. Control characters and extended ascii characters are not allowed. Otherwise, any ascii characters are valid for path names.

#### Root directories

By default, SNOW has three root directories:

* `/static/` is a read-only directory which only contains pre-defined files. The files in this directory may not be changed.
* `/tmp/` is a volatile-storage directory which is cleared when the system resets or is shut off.
* `/home/` is a persistent-storage directory which retains all changes made to it, even if the system is reset or shut down.

#### Limitations

* File names may only be up to `14` characters in length.
* Directories may only contain up to `14` files and subdirectories.
* Currently, files may only be up to 192B in length.

## TODO

* Improve `help` - ideally we would be able to print help text for each command, if available.
* Improve `cat` - needs to be able to accept multiple file arguments, otherwise it's not really 'conCATenate'. Also needs a file output parameter.
* Implement text editor
* Add string parsing and escapes to shell (e.g., so spaces and newlines can be properly provided as parameters)
* Add redirects and pipes to shell, so programs can interact with each other or output to files.
* Increase max file size.