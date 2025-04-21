# Memory management API

These functions are for handling dynamically-allocated memory.
Bank `$7F` is used soley for dynamic memory.

## memAlloc

`[x16]void* memAlloc([s16]int size)`

Allocate at least `size` bytes for use by the current process in bank `$7F`.

If there is not space that can be allocated (either because there is
insufficient memory available, or because currently allocated memory is too
fragmented), then this function will return `NULL`.

Otherwise, this function will return a pointer to the first available byte.

After this function is called, `size` will be updated to the actual number
of bytes allocated. This number will always be larger than the previous number,
unless the allocation operation failed.

## memFree

`memFree([x16]void *ptr)`

Free the memory at `ptr`.

`ptr` *must* be the value that was returned by `memAlloc` (i.e., the pointer
to the first available byte).

## memChangeOwner

`memChangeOwner([x16]void *ptr, [a8]PID process)`

Change the owner of the memory at `ptr` to `process`.

This means that the new owner of the memory is now responsible for freeing
this memory, and this memory will be automatically freed when the new owner
is killed.

This is useful for allocating memory for use by another process.

`ptr` *must* be the value that was returned by `memAlloc` (i.e., the pointer
to the first available byte).
