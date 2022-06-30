.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KPrintAssets" FREE

KPrintFontAsset__:
    .incbin "assets/font_ascii.bin"

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
.DEFINE BG1_TILE_BASE_ADDR $0000
; tile character addresses; granularity is (X % $1000) words
.DEFINE BG1_CHARACTER_BASE_ADDR $1000

KInitPrinter__:
    rep #$30 ; 16b AXY
    stz loword(kTermBufferCount)
    stz loword(kTermOffY)
    stz loword(kTermPrintVMEMPtr)
    sep #$20 ; 8b A
    ; f-blank
    lda #%10001111
    sta.l INIDISP
    ; set addresses
    lda #(BG1_TILE_BASE_ADDR >> 8) | %00
    sta.l BG1SC
    lda #(BG1_CHARACTER_BASE_ADDR >> 12)
    sta.l BG12NBA
    ; show only BG1 on main screen
    lda #%00000001
    sta.l SCRNDESTM
    ; BG mode 0
    lda #%00000000
    sta.l BGMODE
    ; Copy palette
    pea $0000 | bankbyte(KPrintPalette__)
    pea loword(KPrintPalette__)
    jsl KCopyPalette4
    rep #$20
    pla
    pla
    ; copy characters
    pea BG1_CHARACTER_BASE_ADDR
    pea 16 * 16 * 8 * 2 ; 16x16, 2bpp
    sep #$20 ; 8 bit A
    lda #bankbyte(KPrintFontAsset__)
    pha
    pea loword(KPrintFontAsset__)
    jsl KCopyVMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; clear screen
    pea BG1_TILE_BASE_ADDR
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
    sep #$30
    .DisableInt__
    phb
    .ChangeDataBank $7E
; setup
    lda #%10000000
    sta.l VMAIN
    rep #$30 ; 16b AXY
    lda loword(kTermPrintVMEMPtr)
    ; clc
    ; adc #BG1_TILE_BASE_ADDR
    sta.l VMADDR
; print
    ; sep #$20 ; 8b A
    ldx #0
    cpx loword(kTermBufferCount)
    beq @endloop
@loop:
    lda kTermBuffer,X
    and #$00FF
    cmp #'\n'
    bne @putchar
; @newline:
    lda loword(kTermPrintVMEMPtr)
    and #$FFE0
    clc
    adc #$20 ; 32 tiles per row
    and #$03FF
    sta loword(kTermPrintVMEMPtr)
    sta.l VMADDR
    ; clc
    ; adc #BG1_TILE_BASE_ADDR
    bra @continue
@putchar:
    sta.l VMDATA
    lda loword(kTermPrintVMEMPtr)
    inc A
    and #$03FF
    sta loword(kTermPrintVMEMPtr)
@continue:
    ; ++x
    inx
    cpx loword(kTermBufferCount)
    bne @loop
@endloop:
; end loop
    ldx #0
    stx loword(kTermBufferCount)
    
; end
    plb
    sep #$30
    .RestoreInt__
    rtl

; put single character (reg A)
kputc:
    .ACCU 8
    phb
    pha
    .DisableInt__
    .ChangeDataBank $7E
; begin
    ; TODO: obey buffer max size
    rep #$10 ; 16b XY
    ldx loword(kTermBufferCount)
    lda $02,s
    sta loword(kTermBuffer),X
    inx
    stx loword(kTermBufferCount)
; end
    plb
    pla
    .RestoreInt__
    rtl

.ENDS