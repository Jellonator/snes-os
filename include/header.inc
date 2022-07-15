.MEMORYMAP
    DEFAULTSLOT 2
    SLOT 0 $0000 $2000 "SharedMemory" ; RAM mirror slot
    SLOT 1 $2000 $6000 "Registers" ; register slot
    SLOT 2 $8000 $8000 "ROM" ; ROM slot
    SLOT 3 $2000 $E000 "ExtraMemory" ; Non-mirrored RAM slot
    SLOT 4 $0000 $10000 "FullMemory" ; Full RAM slot
    SLOT 5 $0000 $8000 "SRAM" ; SRAM slot
.ENDME

.ROMBANKMAP
    BANKSTOTAL $80
    BANKSIZE $8000
    BANKS $80
.ENDRO
; ROM starts at $80, NOT $00
; This only really matters since we're using FASTROM
.BASE $80

.SNESHEADER
    ID "SNES"
    ; Program title, 21 bytes
    NAME "FamiOS"
    ;    "                     "

    FASTROM
    LOROM

    CARTRIDGETYPE $00 ; $00 = ROM only
    SRAMSIZE $00      ; No SRAM
    COUNTRY $01       ; $01 = U.S.
    LICENSEECODE $00
    VERSION $00
.ENDSNES

.EMPTYFILL $DB