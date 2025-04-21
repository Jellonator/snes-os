# Process management API

Functions for creating, managing, and killing processes.

## procCreate

```
[x8]PID procCreate(
    [s]void args,
    [s16]int nargs,
    [s16]int stack_size,
    [s24]char* name,
    [s24]void *function)
```

Create a new process.

`args` will be pushed to the stack of the new process.
This data is stored directly on the stack.
`nargs` is the number of bytes that will be pushed.

`stack_size` is the minimum number of bytes to be allocated for the process'
direct page.

`name` is a pointer to the process' name.

`function` is the address that the program counter will start at for this process.

## procResume

`procResume([x8]PID process)`

Set the given process' state to 'READY'.
This allows the process to run.

## procSuspend

`procSuspend([x8]PID process)`

Set the given process' state to 'SUSPEND'.
This prevents the process from running.

## procWaitNMI

`procWaitNMI([x8]PID process)`

Set the given process' state to 'WAIT_NMI'.
This prevents the process from running, until the current frame has finished rendering.

## procRechedule

`procReschedule()`

Reschedule the current process. This will immediately end execution, but
execution of this process may resume later if its state is 'READY'.

## procKill

`procKill([x8]PID process)

Kill the given process. This will:
 * Immediately end execution of the process
 * Free process' ID for later use
 * Remove the process' renderer, if it is the active renderer
 * Free any memory owned by this process.

Use caution when calling this function.
Processes which were waiting on this process' semaphores could end up waiting forever.

## procExit

`procExit()`

Kill the current process. See `procKill` for more information.

Call this when your process is finished.
