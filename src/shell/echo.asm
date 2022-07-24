.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shecho" FREE

shEcho_name: .db "echo\0"
shEcho:
    rep #$30 ; 16b AXY
    ; $01,s: int argc
    ; $03,s: char **argv
    lda $03,s
    inc A
    inc A
    tax
    lda $01,s
    beq @end
    dec A
    beq @end
@loop:
    ldy.w $0000,X
    pha
    phx
    php
    jsl kPutString
    sep #$20
    lda #' '
    jsl kPutC
    plp
    plx
    pla
    inx
    inx
    dec A
    bne @loop
@end:
    sep #$20
    lda #'\n'
    jsl kPutC
    jsl procExit

.ENDS