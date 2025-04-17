.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shcat" FREE

_err_oom:
    .db "Could not allocate buffer.\n\0"

_err_no_file_provided:
    .db "Need at least one parameter.\n\0"

_err_could_not_open:
    .db "Could not open file.\n\0"

shCat_name: .db "cat\0"
shCat:
    rep #$30 ; 16b AXY
    ; $01,s: int argc
    ; $03,s: char **argv
    lda $01,S
    cmp #2
    beq +
        phb
        .ChangeDataBank $01
        ldy #_err_no_file_provided
        jsl kPutString
        plb
        jsl procExit
    +:
    ; allocate buffer
    pea 16
    jsl memAlloc
    rep #$30
    pla
    cpx #0
    bne +
        phb
        .ChangeDataBank $01
        ldy #_err_oom
        jsl kPutString
        plb
        jsl procExit
    +:
    stx.b $08
    ; open file
    rep #$30
    lda $03,S
    inc A
    inc A
    tay
    ldx.w $0000,Y
    jsl fsOpen
    rep #$30
    cpx #0
    bne +
        phb
        .ChangeDataBank $01
        ldy #_err_could_not_open
        jsl kPutString
        plb
        jsl procExit
    +:
    stx.b $12
    ; loop read and print
    sep #$20
    lda #$7F
    sta.b $0A
    pha
    rep #$20
    lda.b $08
    pha
    pea 15
    @loop:
        rep #$30
        lda.b $08
        sta $03,S
        ldx.b $12
        jsl fsRead
        rep #$30
        cmp #0
        beq @end_loop
        ; got text
        ; put null terminator
        tay
        lda #0
        sep #$20
        sta [$08],Y
        ldy.b $08
        jsl kPutString
        jmp @loop
    @end_loop:
    .POPN 5
    ; close file
    rep #$30
    ldx.b $12
    jsl fsClose
@end:
    sep #$20
    lda #'\n'
    jsl kPutC
    jsl procExit

.ENDS