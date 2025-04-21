# Reading API documentation

Functions are documented in the following format:

`{return} {function name}({args...})`

For example:

`[x16]fs_device_instance_t* fsOpen([x16]char *filename)`

## Storage

`{storage}` tells how a value is stored.
The first character tells how the value is stored. This can be in a register
(`x`, `y`, or `a`), or on the stack (`s`).

The following number tells you many bits are used to store it.

For storage using `X` or `Y` registers, which also require the data Bank register
to complete the full pointer, then `Bx` or `By` will be written.

Here are some examples:
* `[s24]` - The value is stored as 24 bits (3 bytes) on the stack.
* `[x16]` - The value is stored in all 16 bits of the `X` register. The data
bank register does not matter for this value.
* `[a8]` - The value is stored in the lower 8 bits of the `A` register.
* `[Bx8]` - The value is stored in the bottom 8 bits of the `X` register.
This pointer will be used to access data within the current data bank.


## Name

`{name}` is an alphanumeric identifier.

Function names require a name, to refer to the address where the function is called.

Arguments usually have a name, but serve no functional purpose. Argument names
exist to make documentation better.

## Type

`{type}` is generally optional, but provides additional information about what
kind of information needs to be provided. For example, `char*` type means that
a pointer to a null-terminated string is expected.

## Return

`{return}` (`{storage}{type}`) refers to how a function returns values.

It consists of a `{storage}`, and an optional `{type}`.

`{storage}` tells how the value will be returned, and `{type}` tells what type
it will be.

## Args

`{args...}` is a comma-delimited list of arguments to be provided to a function.

Each element (`{storage}{type} {name}`) refers to a single parameter.

`{storage}` tells how the argument should be provided, `{type}` tells what
should be provided, and `{name}` idenfifies what is being provided.

Stack arguments must be pushed in the order that they are displayed in the function.

## Multiple returns

Sometimes functions have multiple ways to return values.

This can either be explicit (the function has multiple values that it intends
to be used, generally returned via registers), or implicit (the function
modifies values on the stack in predictable ways, which can be used).

Implicit returns will be documented separately (e.g., 'this function will
do something to a value on the stack').

Explicit return values will appear in the function definition, as such:

```
{storage}{type}
{storage}{type}
{function name}({args...})
```
