.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "Test" FREE

_teststr1:
    .db "asdfbar\0"

_teststr2:
    .db "asdffoo\0"

_teststr22:
    .db "asdffooo\0"

_teststr3:
    .db "qwertyuiop\0"

_teststr4:
    .db "baaabaab\0"

_testnum_0:
    .db "0\0"

_testnum_420:
    .db "420\0"

_testnum_32767:
    .db "32767\0"

_testnum_65535:
    .db "65535\0"

_testnum_N420:
    .db "-420\0"

_testnum_N0:
    .db "-0\0"

_testnum_N32767:
    .db "-32767\0"

_testnum_N32768:
    .db "-32768\0"

_teststrempty:
    .db "\0"

.MACRO .StartGroup ARGS groupname
    rep #$10
    ldy #@@@@@\.\@n
    jsl kputstring
    bra @@@@@\.\@a
    @@@@@\.\@n:
    .db groupname, ": \0"
    @@@@@\.\@a:
.ENDM

.MACRO .EndGroup
    sep #$20
    lda #'\n'
    jsl kputc
.ENDM

.MACRO .CheckAEq ARGS value
    cmp #value
    bne @@@@@\@\.@a
    ; ok
    sep #$20
    lda.b #'O'
    bra @@@@@\@\.@b
    @@@@@\@\.@a:
    ; err
    sep #$20
    lda.b #'X'
    @@@@@\@\.@b:
    jsl kputc
.ENDM

.MACRO .CheckXEq ARGS value
    cpx #value
    bne @@@@@\@\.@a
    ; ok
    sep #$20
    lda.b #'O'
    bra @@@@@\@\.@b
    @@@@@\@\.@a:
    ; err
    sep #$20
    lda.b #'X'
    @@@@@\@\.@b:
    jsl kputc
.ENDM

.MACRO .CheckANeq ARGS value
    cmp #value
    beq @@@@@\@\.@a
    ; ok
    sep #$20
    lda.b #'O'
    bra @@@@@\@\.@b
    @@@@@\@\.@a:
    ; err
    sep #$20
    lda.b #'X'
    @@@@@\@\.@b:
    jsl kputc
.ENDM

KTestProgram__:
    .ChangeDataBank $01
    ; TEST memcmp8
    .StartGroup "MEMCMP8"
    rep #$10 ; 16b XY
    sep #$20 ; 8b A
    lda #4
    ldx #_teststr1
    ldy #_teststr2
    jsl memcmp8
    .CheckAEq 0
    rep #$10 ; 16b XY
    sep #$20 ; 8b A
    lda #5
    ldx #_teststr1
    ldy #_teststr2
    jsl memcmp8
    .CheckANeq 0
    rep #$10 ; 16b XY
    sep #$20 ; 8b A
    lda #0
    ldx #_teststr1
    ldy #_teststr3
    jsl memcmp8
    .CheckAEq 0
    rep #$10 ; 16b XY
    sep #$20 ; 8b A
    lda #1
    ldx #_teststr1
    ldy #_teststr3
    jsl memcmp8
    .CheckANeq 0
    .EndGroup
    ; TEST strcmp
    .StartGroup "STRCMP"
    rep #$10 ; 16b XY
    ldx #_teststr1
    ldy #_teststr2
    jsl strcmp
    .ACCU 8
    .CheckAEq -1
    rep #$10 ; 16b XY
    ldx #_teststr2
    ldy #_teststr1
    jsl strcmp
    .ACCU 8
    .CheckAEq 1
    rep #$10 ; 16b XY
    ldx #_teststr2
    ldy #_teststr22
    jsl strcmp
    .ACCU 8
    .CheckAEq -1
    rep #$10 ; 16b XY
    ldx #_teststr22
    ldy #_teststr2
    jsl strcmp
    .ACCU 8
    .CheckAEq 1
    rep #$10 ; 16b XY
    ldx #_teststrempty
    ldy #_teststr2
    jsl strcmp
    .ACCU 8
    .CheckAEq -1
    rep #$10 ; 16b XY
    ldx #_teststr2
    ldy #_teststrempty
    jsl strcmp
    .ACCU 8
    .CheckAEq 1
    rep #$10 ; 16b XY
    ldx #_teststrempty
    ldy #_teststrempty
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$10 ; 16b XY
    ldx #_teststr3
    ldy #_teststr3
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    .EndGroup
    ; TEST strchr
    .StartGroup "STRCHR"
    rep #$10 ; 16b XY
    sep #$20 ; 8b A
    lda #'b'
    ldx #_teststr4
    jsl strchr
    pha
    phx
    php
    .CheckXEq _teststr4
    plp
    plx
    pla
    inx
    jsl strchr
    pha
    phx
    php
    .CheckXEq _teststr4+4
    plp
    plx
    pla
    inx
    jsl strchr
    pha
    phx
    php
    .CheckXEq _teststr4+7
    plp
    plx
    pla
    inx
    jsl strchr
    pha
    phx
    php
    .CheckXEq 0
    plp
    plx
    pla
    inx
    .EndGroup
    ; TEST strlen
    .StartGroup "STRLEN"
    rep #$10
    ldx #_teststrempty
    jsl strlen
    .ACCU 16
    .CheckAEq 0
    rep #$10
    ldx #_teststr1
    jsl strlen
    .ACCU 16
    .CheckAEq 7
    rep #$10
    ldx #_teststr22
    jsl strlen
    .ACCU 16
    .CheckAEq 8
    .EndGroup
    ; TEST strtouw
    .StartGroup "STRTOUW"
    rep #$10
    ldx #_testnum_420
    jsl strtouw
    .ACCU 16
    .CheckAEq 420
    rep #$10
    ldx #_testnum_32767
    jsl strtouw
    .ACCU 16
    .CheckAEq 32767
    rep #$10
    ldx #_testnum_65535
    jsl strtouw
    .ACCU 16
    .CheckAEq 65535
    rep #$10
    ldx #_testnum_0
    jsl strtouw
    .ACCU 16
    .CheckAEq 0
    .EndGroup
    ; TEST strtoiw
    .StartGroup "STRTOIW"
    rep #$10
    ldx #_testnum_420
    jsl strtoiw
    .ACCU 16
    .CheckAEq 420
    rep #$10
    ldx #_testnum_32767
    jsl strtoiw
    .ACCU 16
    .CheckAEq 32767
    rep #$10
    ldx #_testnum_0
    jsl strtoiw
    .ACCU 16
    .CheckAEq 0
    rep #$10
    ldx #_testnum_N0
    jsl strtoiw
    .ACCU 16
    .CheckAEq 0
    rep #$10
    ldx #_testnum_N420
    jsl strtoiw
    .ACCU 16
    .CheckAEq -420
    rep #$10
    ldx #_testnum_N32767
    jsl strtoiw
    .ACCU 16
    .CheckAEq -32767
    rep #$10
    ldx #_testnum_N32768
    jsl strtoiw
    .ACCU 16
    .CheckAEq -32768
    .EndGroup
    ; TEST writeuw
    .StartGroup "WRITEUW"
    rep #$30 ; 16b AXY
    tdc
    clc
    adc #$08
    sta.b $06 ; $06 = string buf
    tax ; X = D + 8
    lda #420
    jsl writeuw
    ldx.b $06
    ldy.w #_testnum_420
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #0
    jsl writeuw
    ldx.b $06
    ldy.w #_testnum_0
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #32767
    jsl writeuw
    ldx.b $06
    ldy.w #_testnum_32767
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #65535
    jsl writeuw
    ldx.b $06
    ldy.w #_testnum_65535
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    .EndGroup
    ; TEST writeiw
    .StartGroup "WRITEIW"
    rep #$30 ; 16b AXY
    tdc
    clc
    adc #$08
    sta.b $06 ; $06 = string buf
    tax ; X = D + 8
    lda #420
    jsl writeiw
    ldx.b $06
    ldy.w #_testnum_420
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #0
    jsl writeiw
    ldx.b $06
    ldy.w #_testnum_0
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #32767
    jsl writeiw
    ldx.b $06
    ldy.w #_testnum_32767
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #-32767
    jsl writeiw
    ldx.b $06
    ldy.w #_testnum_N32767
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #-32768
    jsl writeiw
    ldx.b $06
    ldy.w #_testnum_N32768
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    rep #$30 ; 16b AXY
    ldx.b $06
    lda #-420
    jsl writeiw
    ldx.b $06
    ldy.w #_testnum_N420
    jsl strcmp
    .ACCU 8
    .CheckAEq 0
    .EndGroup

    ; end
    @loop:
    jmp @loop

.ENDS