.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shcp" FREE

_err_oom:
    .db "Could not allocate buffer.\n\0"

_err_no_file_provided:
    .db "Need two parameters.\n\0"

_err_could_not_create:
    .db "Could not create file.\n\0"

_err_could_not_open:
    .db "Could not open file.\n\0"

.DEFINE SOURCE_FH $12
.DEFINE DEST_FH $14
.DEFINE BUFFER $16

shCp_name: .db "cp\0"
shCp:
    rep #$30 ; 16b AXY
    ; $01,s: int argc
    ; $03,s: char **argv
    lda $01,S
    cmp #3
    beq +
        phb
        .ChangeDataBank $01
        ldy #_err_no_file_provided
        jsl kPutString
        plb
        jsl procExit
    +:
    ; allocate buffer
    pea 33
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
    stx.b BUFFER
    ; open file
    rep #$30
    lda $03,S
    clc
    adc #2
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
    stx.b SOURCE_FH
    ; create file
    rep #$30
    lda $03,S
    clc
    adc #4
    tay
    ldx.w $0000,Y
    jsl fsCreate
    rep #$30
    cpx #0
    bne +
        ldx.b SOURCE_FH
        jsl fsClose
        rep #$30
        phb
        .ChangeDataBank $01
        ldy #_err_could_not_create
        jsl kPutString
        plb
        jsl procExit
    +:
    stx.b DEST_FH
    ; loop read and write
    ; pea 0
    sep #$20
    lda #$7F
    pha
    rep #$20
    lda.b BUFFER
    pha
    pea 32
    @loop:
        rep #$30
        lda #32
        sta $01,S
        ldx.b SOURCE_FH
        ; sta $06,S
        jsl fsRead
        rep #$30
        cmp #0
        beq @end_loop
        sta $01,S
        ldx.b DEST_FH
        ; sta $06,S
        jsl fsWrite
        rep #$30
        jmp @loop
    @end_loop:
    ; close file
    rep #$30
    ldx.b SOURCE_FH
    jsl fsClose
    rep #$30
    ldx.b DEST_FH
    jsl fsClose
@end:
    jsl procExit

.ENDS