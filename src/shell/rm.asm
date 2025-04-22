.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shcat" FREE

_err_no_file_provided:
    .db "Need at least one parameter.\n\0"

_err_could_not_remove:
    .db "Could not remove file or\ndirectory.\n\0"

shRm_name: .db "rm\0"
shRm:
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
    ; remove directory
    rep #$30
    lda $03,S
    inc A
    inc A
    tay
    ldx.w $0000,Y
    jsl fsRemove
    rep #$30
    cmp #0
    bne +
        phb
        phk
        plb
        ldy #_err_could_not_remove
        jsl kPutString
        plb
        jsl procExit
    +:
@end:
    jsl procExit

.ENDS