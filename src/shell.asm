.include "base.inc"

.BANK $02 SLOT "ROM"
.SECTION "ShellAssets" FREE

ShellTextPalette__:
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 31, 31, 31
    .DCOLOR_RGB5 20, 16, 22
    .DCOLOR_RGB5 11, 11, 11

ShellBackPalette__:
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 20, 16, 22
    .DCOLOR_RGB5  8,  8,  8
    .DCOLOR_RGB5  6,  6,  6

ShellBackgroundData__:
    ; line 0-1
    .dsw 64 $0000
    ; line 2
    .dw $0000, $0010
    .dsw 28 $0011
    .dw $0012, $0000
    ; line 3-9
    .REPT 7
    .dw $0000, $0020
    .dsw 28 $0021
    .dw $0022, $0000
    .ENDR
    ; line 10
    .dw $0000, $0030
    .dsw 28 $0031
    .dw $0032, $0000
    ; line 11-31
    .REPT 21
    .dsw 32 $0000
    .ENDR

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "Shell" FREE

; tile data addresses; granularity is (X % $0400) words
.DEFINE BG1_SHELLTEXT_TILE_BASE_ADDR $0400
.DEFINE BG2_SHELLBACK_TILE_BASE_ADDR $0800
.DEFINE BG4_DISPTEXT_TILE_BASE_ADDR $0000
; tile character addresses; granularity is (X % $1000) words
.DEFINE BG2_SHELLBACK_CHAR_BASE_ADDR $2000
.DEFINE BG4_DISPTEXT_CHAR_BASE_ADDR $1000
; BG4 refers to data from kprint.asm

.DEFINE DEADZONE_LEFT 2 ; screen offset from left
.DEFINE MAX_LINE_WIDTH 28 ; maximum of 28 characters per row
.DEFINE ROW_START 25 ; row to start writing to

.ENUMID 0
.ENUMID STATE_HIDDEN
.ENUMID STATE_LOWER
.ENUMID STATE_UPPER
.ENUMID STATE_CAPS
.ENUMID STATE_SYMBOLS

.DEFINE SHFLAG_UPDATE_CHARS $80

; variables
.ENUM $00
    bState db
    bSelectIdx db
    bNChars db
    bFlags db
    wVMEMPtr dw
    pwStrBuf dw
.ENDE

_shell_hide_ui:
    ; show only BG4 on main screen
    lda #%00001000
    sta.l SCRNDESTM
    stz.b bState
    rts

_shell_show_ui:
    sep #$30 ; 8b AXY
    ; Show BGs 1, 2, and 4
    lda #%00001011
    sta.l SCRNDESTM
    lda #STATE_LOWER
    sta.b bState
    lda #SHFLAG_UPDATE_CHARS
    sta.b bFlags
    rts

_shell_update_charset:
    sep #$20 ; 8b A
    rep #$10 ; 16b XY
    lda.b bState
    cmp #STATE_UPPER
    beq @upper
    cmp #STATE_CAPS
    beq @upper
    cmp #STATE_SYMBOLS
    beq @sym
    ldx #__ShellSymLower
    bra +
@upper:
    ldx #__ShellSymUpper
    bra +
@sym:
    ldx #_ShellSymSymbols
+:
    lda #80
    sta VMAIN
    rep #$20
    ; phb
    ; .ChangeDataBank bankbyte(__ShellSymLower)
    .REPT 4 INDEX i
        lda #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (i + 1)) + 2
        sta.l VMADDR
        ldy #10
    -:
        lda.l (__ShellSymLower&$FF0000),X
        and #$00FF
        inx
        sta.l VMDATA
        lda #0
        sta.l VMDATA
        dey
        bne -
    .ENDR
    ; lda #$0036
    ; sta.l VMDATA
    ; lda #$0039
    ; sta.l VMDATA
; end
    ; plb
    rts

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
    ; disable rendering and interrupts
    sep #$20
    .DisableInt__
    lda #%10001111
    sta.l INIDISP
; first, upload graphics
    ; upload UI
    pea BG2_SHELLBACK_CHAR_BASE_ADDR
    pea 16 * 4 * 8 * 2 ; 16x4, 2bpp
    sep #$20 ; 8 bit A
    lda #bankbyte(sprites@ShellUIAsset__)
    pha
    pea loword(sprites@ShellUIAsset__)
    jsl KCopyVMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; clear text screen
    pea BG1_SHELLTEXT_TILE_BASE_ADDR
    pea 32*32*2 ; 32x32 tiles
    jsl KClearVMem
    rep #$20 ; 16b A
    pla
    pla
    ; set background screen
    pea BG2_SHELLBACK_TILE_BASE_ADDR
    pea 32*32*2 ; 32x32 tiles
    sep #$20
    lda #bankbyte(ShellBackgroundData__)
    pha
    pea loword(ShellBackgroundData__)
    jsl KCopyVMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; copy palette
    pea $6000 | bankbyte(ShellTextPalette__)
    pea loword(ShellTextPalette__)
    jsl KCopyPalette4
    sep #$20 ; 8b A
    lda #$00
    sta $04,s
    jsl KCopyPalette4
    rep #$20
    pla
    pla
    pea $2000 | bankbyte(ShellBackPalette__)
    pea loword(ShellBackPalette__)
    jsl KCopyPalette4
    rep #$20
    pla
    pla
    ; update mem registers
    sep #$20
    lda #(BG1_SHELLTEXT_TILE_BASE_ADDR >> 8) | %00
    sta.l BG1SC
    lda #(BG2_SHELLBACK_TILE_BASE_ADDR >> 8) | %00
    sta.l BG2SC
    lda #(BG4_DISPTEXT_CHAR_BASE_ADDR >> 12) | (BG2_SHELLBACK_CHAR_BASE_ADDR >> 8)
    sta.l BG12NBA
    lda #%00001011
    sta.l SCRNDESTM
    ; initialize other
    jsr _shell_update_charset
    pea 64
    jsl memalloc
    stx.b pwStrBuf
    rep #$20
    pla
    ldy #0
    sep #$20
    -:
    sta (pwStrBuf),Y
    iny
    dec A
    bne -
    ; set renderer
    sep #$20
    lda #bankbyte(_shell_render)
    pha
    rep #$20
    lda #loword(_shell_render)
    pha
    jsl KSetRenderer
    sep #$20
    pla
    pla
    pla
; end
    ; re-enable rendering and interrupts
    sep #$20 ; 8b A
    lda #%00001111
    sta.l INIDISP
    .RestoreInt__
    rts

_shell_render:
    jsl KUpdatePrinter__
    rtl

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