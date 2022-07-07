.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "Shell" FREE

; tile data addresses; granularity is (X % $0400) words
.DEFINE BG_TILE_BASE_ADDR $0400
; tile character addresses; granularity is (X % $1000) words
.DEFINE BG_CHARACTER_BASE_ADDR $3000

.DEFINE DEADZONE_LEFT 2 ; screen offset from left
.DEFINE MAX_LINE_WIDTH 28 ; maximum of 28 characters per row
.DEFINE ROW_START 25 ; row to start writing to

; variables
.ENUM $00
    bNChars db
    wVMEMPtr dw
    pStrBuf dl
.ENDE

__ShellSymLower:
    .db "1234567890"
    .db "abcdefghij"
    .db "klmnopqrst"
    .db "uvwxyz.,?!"

__ShellSymUpper:
    .db "!@#$%^&*()"
    .db "ABCDEFGHIJ"
    .db "KLMNOPQRST"
    .db "UVWXYZ"
    .db '"'
    .db "':;"

_ShellSymSymbols:
    .db "!@#$%^&*()"
    .db ";:"
    .db '\'
    .db "/[]{}<>"
    .db "+-=_|     "
    .db ".,?!`~"
    .db '"'
    .db "':;"

_shell_init:
    rts

_shell_update:
    rts

os_shell:
    jsr _shell_init
    @loop:
        jsr _shell_update
        jmp @loop

_sh_help:
    rtl

_sh_ps:
    rtl

_sh_kill:
    rtl

_sh_clear:
    rtl

_sh_echo:
    rtl

_sh_uptime:
    rtl

.ENDS