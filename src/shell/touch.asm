.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shcat" FREE

_err_no_file_provided:
    .db "Need at least one parameter.\n\0"

_err_could_not_create:
    .db "Could not create file.\n\0"

shTouch_name: .db "touch\0"
shTouch:
    rep #$30 ; 16b AXY
    ; $01,s: int argc
    ; $03,s: char **argv
    lda $01,S
    cmp #2
    beq +
        phb
        phk
        plb
        ldy #_err_no_file_provided
        jsl kPutString
        plb
        jsl procExit
    +:
    ; create file
    rep #$30
    lda $03,S
    inc A
    inc A
    tay
    ldx.w $0000,Y
    jsl fsCreate
    rep #$30
    cpx #0
    bne +
        phb
        phk
        plb
        ldy #_err_could_not_create
        jsl kPutString
        plb
        jsl procExit
    +:
    stx.b $12
    ; close file
    rep #$30
    ldx.b $12
    jsl fsClose
@end:
    jsl procExit

.ENDS