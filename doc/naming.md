This isn't the 90s, function names don't need to be super brief.
In general, prefer camelCase.

Certain groups of functions start with a given prefix, e.g. vCopyMem.
Prefixes:

* v - video functions
* k - internal kernel functions
* sem - semaphore management
* queue - process queue management
* proc - process management
* mem - memory management
* sh - shell functions

Standard library functions do not have a set prefix

Nouns are used for variables, and verbs are used for functions.
Structs begin with an uppercase letter.

Macros should start with a period

functions ending with two underscores (e.g. kVBlank__)
shouldn't be used in user code.