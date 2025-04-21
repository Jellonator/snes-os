# Standard library functions

## memoryCmp8

`[a8]int memoryCmp8([Bx16]void* a, [By16]void *b, [a8]size)`

Compare `size` bytes between `a` and `b`.

If `a` and `b` are equal, returns `0`.
If the first non-equal byte of `a` is less than that of `b`, returns `-1`.
Otherwise, returns `1`.

## stringCmp

`[a8]int strCmp([Bx16]char *a, [By16]char *b)`

Compare null-terminated strings `a` and `b`.

If `a` and `b` are equal, returns `0`.
If `a` is lexographically before `b`, returns `-1`.
Otherwise, returns `1`.

## stringCmpL

`[a8]int strCmpL([s24]char *a, [s24]char *b)`

Compare null-terminated strings `a` and `b`.

If `a` and `b` are equal, returns `0`.
If `a` is lexographically before `b`, returns `-1`.
Otherwise, returns `1`.

## stringFindChar

`[x16]char* stringFindChar([Bx16]char* string, [a8]char target)`

Returns a pointer to the first occurence of `target` in `string`.

If no such character exists in `string`, returns `NULL`.

## stringLen

`[a16]int stringLen([Bx16]char* string)`

Returns the length of `string` (number of characters before null terminator).

## stringToU16

```
[a16]int value
[Bx16]char* next
stringToU16([Bx16]char* string)
```

Convert the given string `string` to a 16-bit unsigned integer in `value`.

After calling, `next` will point to the character where parsing ended.

You can check if the given string was a valid integer by checking if `*next == 0`
(that is, we reached the end of the string).

## stringToI16

```
[a16]signed int value
[Bx16]char* next
stringToU16([Bx16]char* string)
```

Convert the given string `string` to a 16-bit signed integer in `value`.

After calling, `next` will point to the character where parsing ended.

You can check if the given string was a valid integer by checking if `*next == 0`
(that is, we reached the end of the string).

## writePtr8

`[Bx16]char* writePtr8([Bx16]char* buffer, [a8]int ptr)`

Write the given 8-bit pointer `ptr` to `buffer`.

In essence, we write two hexadecimal characters to `buffer` indicating the value of `ptr`.

Returns a pointer to the end of the string.

## writePtr16

`[Bx16]char* writePtr8([Bx16]char* buffer, [a16]int ptr)`

Write the given 16-bit pointer `ptr` to `buffer`.

In essence, we write four hexadecimal characters to `buffer` indicating the value of `ptr`.

Returns a pointer to the end of the string.

## writeU16

`[Bx16]char* writeU16([Bx16]char* buffer, [a16]unsigned int value)`

Write the unsigned decimal value of `value` to `buffer`.
This may write between one and five characters to `bufer`.

Note that `value` should *not* be in BCD.

Returns a pointer to the end of the string.

## writeI16

`[Bx16]char* writeI16([Bx16]char* buffer, [a16]signed int value)`

Write the signed decimal value of `value` to `buffer`.
This may write between one and six characters to `bufer`.

Note that `value` should *not* be in BCD.

Returns a pointer to the end of the string.

## writeChar

`[Bx16]char* writeChar([Bx16]char* buffer, [a8] char)`

Write a single character `char` to `buffer`.

Returns a pointer to the end of the string.
