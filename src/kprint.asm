.include "base.inc"

.BANK $02 SLOT "ROM"
.SECTION "KPrintAssets" FREE

.include "assets.inc"

KPrintPalette__:
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 31, 31, 31
    .DCOLOR_RGB5 20, 16, 22
    .DCOLOR_RGB5 11, 11, 11

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "KPrint" FREE

; printer VRAM slots
; VRAM is 64KB of 16b words addressed $0000-$7FFF

; tile data addresses; granularity is (X % $0400) words
.DEFINE BG4_TILE_BASE_ADDR $0000
; tile character addresses; granularity is (X % $1000) words
.DEFINE BG4_CHARACTER_BASE_ADDR $1000

; ntsc TVs may hide some or all of the screen, so this zone is defined to
; prevent text being printed to unreadable sections of the screen
.DEFINE DEADZONE_LEFT 2 ; screen offset from left
.DEFINE MAX_TERM_WIDTH 28 ; maximum of 28 characters per row
.DEFINE ROW_START 25 ; row to start writing to

KPrintNextRow__:
    ; update vmem ptr
    rep #$20
    lda loword(kTermPrintVMEMPtr)
    and #$FFE0
    clc
    adc #$20
    and #$03FF
    sta loword(kTermPrintVMEMPtr)
    ; clear incoming line
    clc
    adc #$20 * 2
    and #$03FF
    clc
    adc #BG4_TILE_BASE_ADDR
    pha
    pea 32*2
    jsl KClearVMem
    rep #$20 ; 16b A
    pla
    pla
    lda loword(kTermPrintVMEMPtr)
    sta.l VMADDR
    ; update offset
    lda loword(kTermOffY)
    clc
    adc #8
    sta loword(kTermOffY)    
    sep #$20 ; 8b A
    sta.l BG4VOFS
    xba
    sta.l BG4VOFS
    rtl

KInitPrinter__:
    rep #$30 ; 16b AXY
    stz loword(kTermBufferCount)
    lda #0
    sta loword(kTermOffY)
    lda #ROW_START*32
    sta loword(kTermPrintVMEMPtr)
    sep #$20 ; 8b A
    stz loword(kTermBufferLoop)
    ; f-blank
    lda #%10001111
    sta.l INIDISP
    ; set scroll
    lda #-DEADZONE_LEFT*8
    sta.l BG4HOFS
    lda #0
    sta.l BG4HOFS
    ; set addresses
    lda #(BG4_TILE_BASE_ADDR >> 8) | %00
    sta.l BG4SC
    lda #(BG4_CHARACTER_BASE_ADDR >> 8)
    sta.l BG34NBA
    ; show only BG4 on main screen
    lda #%00001000
    sta.l SCRNDESTM
    ; BG mode 0
    lda #%00000000
    sta.l BGMODE
    ; Copy palette
    pea $6000 | bankbyte(KPrintPalette__)
    pea loword(KPrintPalette__)
    jsl KCopyPalette4
    sep #$20 ; 8b A
    lda #$00
    sta $04,s
    jsl KCopyPalette4
    rep #$20
    pla
    pla

    ; copy characters
    pea BG4_CHARACTER_BASE_ADDR
    pea 16 * 16 * 8 * 2 ; 16x16, 2bpp
    sep #$20 ; 8 bit A
    lda #bankbyte(sprites@KPrintFontAsset__)
    pha
    pea loword(sprites@KPrintFontAsset__)
    jsl KCopyVMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; clear screen
    pea BG4_TILE_BASE_ADDR
    pea 32*32*2
    jsl KClearVMem
    rep #$20 ; 16b A
    pla
    pla
    ; enable rendering
    sep #$20 ; 8b A
    lda #%00001111
    sta.l INIDISP
    rtl

; Update printer during vblank
KUpdatePrinter__:
    phb
    .ChangeDataBank $7E
; setup
    sep #$30 ; 8b AXY
    lda #%10000000
    sta.l VMAIN
    rep #$30 ; 16b AXY
    lda loword(kTermPrintVMEMPtr)
    sta.l VMADDR
; print
    sep #$20 ; 8b A
    lda loword(kTermBufferLoop)
    bne +
    ; no buffer loop
    ldx #0
    cpx loword(kTermBufferCount)
    beq @endloop
    rep #$20 ; 16b A
    bra @loop
    +:
    ; perform buffer loop
    ldx loword(kTermBufferCount)
    stz loword(kTermBufferLoop)
    rep #$20 ; 16b A
@loop:
    cpx #KTERM_MAX_BUFFER_SIZE
    bne +
    ldx #0
    +:
    lda kTermBuffer,X
    and #$00FF
    cmp #'\n'
    bne @putchar
; @newline:
    jsl KPrintNextRow__
    rep #$30 ; 16b AXY
    bra @continue
@putchar:
    sta.l VMDATA
    lda loword(kTermPrintVMEMPtr)
    and #$001F
    cmp #MAX_TERM_WIDTH-1
    bne +
    jsl KPrintNextRow__
    rep #$30 ; 16b AXY
    jmp @continue
    +:
    inc loword(kTermPrintVMEMPtr)
@continue:
    inx
    cpx loword(kTermBufferCount)
    bne @loop
@endloop:
; end loop
    ldx #0
    stx loword(kTermBufferCount)
; end
    plb
    rtl

; put single character (reg A, 8b)
kputc:
    .ACCU 8
    phb
    pha
    .ChangeDataBank $7E
    .DisableInt__
; begin
    rep #$10 ; 16b XY
    ldx loword(kTermBufferCount)
    cpx #KTERM_MAX_BUFFER_SIZE
    bne +
    ; buffer loop
        ldx #0
        lda #1
        sta loword(kTermBufferLoop)
    +:
    lda $02,s
    sta loword(kTermBuffer),X
    inx
    stx loword(kTermBufferCount)
; end
    .RestoreInt__
    pla
    plb
    rtl

; put string from pointer Y into string buffer
; XY should be 16b
kputstring:
    .INDEX 16
    sep #$20 ; 8b A
    .DisableInt__
; begin
    rep #$20 ; 16b A
    lda.l kTermBufferCount
    tax
    sep #$20 ; 8b A
@loop:
    cpx #KTERM_MAX_BUFFER_SIZE
    bne +
    ldx #0
    lda #1
    sta.l kTermBufferLoop
    +:
    lda.w $0000,Y
    beq @end
    sta.l kTermBuffer,X
    iny
    inx
    bra @loop
@end:
    rep #$20 ; 16b A
    txa
    sta.l kTermBufferCount
;end
    sep #$20 ; 8b A
    .RestoreInt__
    rtl



.ENDS