# Filesystem API

## fsOpen

`[x16]fs_handle_instance_t* fsOpen([Bx16]char* filename)`

Tries to open the file with the name `filename`.

If this operation fails, returns `NULL`.

Otherwise, returns a file handle to the open file.

This may fail if:
 * `filename` is invalid
 * There is no file with the name `filename`

## fsClose

`fsClose([x16]fs_handle_instance_t* handle)`

Close the given file handle.

## fsSeek

`fsSeek([x16]fs_handle_instance_t* handle, [a16]int fileptr)`

Seek the open file handle to the given file pointer.

## fsRead

`[a16]int fsRead([x16]fs_handle_instance_t* handle, [s24]void* buffer, [s24]int size)`

Read `size` bytes from the given file into `buffer`.

Returns the number of bytes that were read.

If this function returns `0` and `size` is not `0`, then it is likely that we
have reached the end of the file.

## fsWrite

`[a16] fsWrite([x16]fs_handle_instance_t* handle, [s24]void* buffer, [s16]int size)`

Write `size` bytes from `buffer` into the given file.

Returns the number of bytes that were written.

If the returned number of bytes is not equal to `size`, then it is likely that
the maximum file size has been reached.

## fsRemove

`[a16]bool fsRemove([Bx16]char* name)`

Deletes the file or directory with the name `name`.

Returns `TRUE` if this operation succeeded.

This may fail if:
 * the file does not exist
 * `name` is invalid
 * the node at `name` is a directory with at least one linked file.

## fsMakeDir

`[a16]bool fsMakeDir([Bx16]char *name)`

Create a new directory at `name`.

Returns `TRUE` if this operation succeeded.

May fail if:
 * `name` is invalid
 * the parent directory does not exist
 * the parent node is not a directory
 * the root directory has no free space
 * a node with this name already exists

## fsCreate

`[x16]fs_handle_instance_t* fsCreate([Bx16]char* name)`

Create a new file at `name`.

Returns a handle to the newly created file if this operation succeeded.
Otherwise, returns `NULL`.

May fail if:
 * `name` is invalid
 * the parent directory does not exist
 * the parent node is not a directory
 * the root directory has no free space
 * a node with this name already exists