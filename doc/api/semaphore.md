# Semaphore API

Semaphores are used for synchronizing data between processes.

A process will use `semWait` to wait for data to become available,
and another process will use `semSignal` to indicate that data is available
for another process to use.

Memory will need to be allocated separately from the semaphore to store the
data that is to be shared between processes.

## semCreate

`[x8]SID semCreate([a8]int initial_value)`

Create a new semaphore, with the value initialized to `initial_value`.

## semWait

`semWait([x8]SID semaphore)`

Wait on the given semaphore.

This function will decrement the semaphore's value.

If the semaphore's previous value is zero or less, then
the current process' state will be set to 'WAIT_SEM' and the current process
will be rescheduled.

## semSignal

`semSignal([x8]SID semaphore)`

Signal to the given semaphore.

This function will increment the semaphore's value.

If there are any waiting processes, then this will resume one waiting process.

## semDelete

`semDelete([x8]SID semaphore)`

Free the given semaphore.

If there are any waiting processes, then kill those processes.
