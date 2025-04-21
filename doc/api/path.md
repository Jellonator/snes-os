# File path API

Helper functions for handling file paths.

## pathIsAbsolute

`[a8]bool pathIsAbsolute([Bx16]char* path)`

Returns `true` if the given path is an absolute path (begins with '/').

## pathIsRelative

`[a8]bool pathIsRelative([Bx16]char* path)`

Returns `true` if the given path is a relative path (does not begin with '/', is not empty).

## pathIsEmpty

`[a8]bool pathIsRelative([Bx16]char* path)`

Returns `true` if the given path is not empty.

## pathIsName

`[a8]bool pathIsName([Bx16]char* path)`

Returns `true` if the given path is a 'name' (path is not empty and does not contain '/' anywhere)

## pathGetTailPtr

`[Bx16]bool pathGetTailPtr([Bx16]char* path)`

Get the pointer to this path's tail. That is, the pointer will be incremented to
the position after the first '/', or to the end of the string failing this.

If the first character of 'path' is a '/', then it will be skipped.

## pathValidate

`[a8]bool pathValidate([Bx16]char* path)`

Returns true if the given path is valid. This means:
 * The path only contains valid characters (no control characters, no DEL, no extended ascii characters).
 * There are no more than 'FS_MAX_FILENAME_LEN' (14) characters per path piece
 * The string is not empty
 * '//' does not occur in the string

## pathPieceCmp

`[a8]int pathPieceCmp([s24]char* path1, [s24]char* path2)`

Compares the first path piece (all characters before the first '/') of `path1` and `path2`.

If both pieces are equivalent, returns `0`.

If the first piece is lexographically before the second piece, then returns `-1`.

Otherwise, returns `1`.

## pathSplitIntoBuffer

`pathSplitIntoBuffer([s24]char* source, [s24]char* dest)`

Copy the first path piece from `source` into `dest`, followed by a null terminator.

After running:
 * `source` will be incremented to the end of the first piece (`*source` will either be '/' or 0).
 * `dest` will be incremented to the end of the string (`*dest` will be 0).