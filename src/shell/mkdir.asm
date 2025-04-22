.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shcat" FREE

_err_no_file_provided:
    .db "Need at least one parameter.\n\0"

_err_could_not_create:
    .db "Could not create directory.\n\0"

shMkdir_name: .db "mkdir\0"
shMkdir:
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
    ; create directory
    rep #$30
    lda $03,S
    inc A
    inc A
    tay
    ldx.w $0000,Y
    jsl fsMakeDir
    rep #$30
    cmp #0
    bne +
        phb
        phk
        plb
        ldy #_err_could_not_create
        jsl kPutString
        plb
        jsl procExit
    +:
@end:
    jsl procExit

.ENDS