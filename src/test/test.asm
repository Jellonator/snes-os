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

_test_invalid_path1:
    .db "\0"

_test_invalid_path2:
    .db "/home/foo//bar\0"

_test_invalid_path3:
    .db "/home/abcdefghijklmnop/foo\0"

_test_valid_path1:
    .db "/home/foo/bar\0"

_test_valid_path1_piece1:
    .db "home\0"

_test_valid_path1_piece2:
    .db "foo\0"

_test_valid_path1_piece3:
    .db "bar\0"

_test_valid_path2:
    .db "/\0"

_test_valid_path3:
    .db "/static/data/"

_test_valid_path3_piece1:
    .db "static\0"

_test_valid_path3_piece2:
    .db "data\0"

_test_valid_path4:
    .db "abcdefghijklmn/opqrstuvwxyz12\0"

_test_valid_path4_piece1:
    .db "abcdefghijklmn"
; no NULL at end needed

_test_valid_path4_piece2:
    .db "opqrstuvwxyz12"
; no NULL at end needed

_test_valid_path5:
    .db ".\0"

_test_fs_mount_temp:
    .db "tmp\0"

_test_path_rom1:
    .db "/static/foo\0"

_test_path_rom2:
    .db "/static/bar\0"

_test_path_rom3:
    .db "/static/hello/world\0"

_test_path_rom_invalidfile1:
    .db "/static/baz\0"

_test_path_rom_invalidfile2:
    .db "/static/hello/foo\0"

.MACRO .StartGroup ARGS groupname
    rep #$10
    ldy #@@@@@\.\@n
    jsl kPutString
    bra @@@@@\.\@a
    @@@@@\.\@n:
    .db groupname
    .db ":"
    .REPT (16-groupname.length)
        .db " "
    .ENDR
    .db "\0"
    @@@@@\.\@a:
.ENDM

.MACRO .EndGroup
    sep #$20
    lda #'\n'
    jsl kPutC
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
    jsl kPutC
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
    jsl kPutC
.ENDM

.MACRO .CheckYEq ARGS value
    cpy #value
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
    jsl kPutC
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
    jsl kPutC
.ENDM


shTest_name: .db "test\0"
shTest
    .ChangeDataBank $01
    ; TEST memoryCmp8
    .StartGroup "memoryCmp8"
        rep #$10 ; 16b XY
        sep #$20 ; 8b A
        lda #4
        ldx #_teststr1
        ldy #_teststr2
        jsl memoryCmp8
        .CheckAEq 0
        rep #$10 ; 16b XY
        sep #$20 ; 8b A
        lda #5
        ldx #_teststr1
        ldy #_teststr2
        jsl memoryCmp8
        .CheckANeq 0
        rep #$10 ; 16b XY
        sep #$20 ; 8b A
        lda #0
        ldx #_teststr1
        ldy #_teststr3
        jsl memoryCmp8
        .CheckAEq 0
        rep #$10 ; 16b XY
        sep #$20 ; 8b A
        lda #1
        ldx #_teststr1
        ldy #_teststr3
        jsl memoryCmp8
        .CheckANeq 0
    .EndGroup
    ; TEST stringCmp
    .StartGroup "stringCmp"
        rep #$10 ; 16b XY
        ldx #_teststr1
        ldy #_teststr2
        jsl stringCmp
        .ACCU 8
        .CheckAEq -1
        rep #$10 ; 16b XY
        ldx #_teststr2
        ldy #_teststr1
        jsl stringCmp
        .ACCU 8
        .CheckAEq 1
        rep #$10 ; 16b XY
        ldx #_teststr2
        ldy #_teststr22
        jsl stringCmp
        .ACCU 8
        .CheckAEq -1
        rep #$10 ; 16b XY
        ldx #_teststr22
        ldy #_teststr2
        jsl stringCmp
        .ACCU 8
        .CheckAEq 1
        rep #$10 ; 16b XY
        ldx #_teststrempty
        ldy #_teststr2
        jsl stringCmp
        .ACCU 8
        .CheckAEq -1
        rep #$10 ; 16b XY
        ldx #_teststr2
        ldy #_teststrempty
        jsl stringCmp
        .ACCU 8
        .CheckAEq 1
        rep #$10 ; 16b XY
        ldx #_teststrempty
        ldy #_teststrempty
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$10 ; 16b XY
        ldx #_teststr3
        ldy #_teststr3
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
    .EndGroup
    ; TEST stringCmpL
    .StartGroup "stringCmpL"
        .PEAL _teststr1
        .PEAL _teststr2
        jsl stringCmpL
        .ACCU 8
        .CheckAEq -1
        .POPN 6
        .PEAL _teststr2
        .PEAL _teststr1
        jsl stringCmpL
        .ACCU 8
        .CheckAEq 1
        .POPN 6
        .PEAL _teststr2
        .PEAL _teststr22
        jsl stringCmpL
        .ACCU 8
        .CheckAEq -1
        .POPN 6
        .PEAL _teststr22
        .PEAL _teststr2
        jsl stringCmpL
        .ACCU 8
        .CheckAEq 1
        .POPN 6
        .PEAL _teststrempty
        .PEAL _teststr2
        jsl stringCmpL
        .ACCU 8
        .CheckAEq -1
        .POPN 6
        .PEAL _teststr2
        .PEAL _teststrempty
        jsl stringCmpL
        .ACCU 8
        .CheckAEq 1
        .POPN 6
        .PEAL _teststrempty
        .PEAL _teststrempty
        jsl stringCmpL
        .ACCU 8
        .CheckAEq 0
        .POPN 6
        .PEAL _teststr3
        .PEAL _teststr3
        jsl stringCmpL
        .ACCU 8
        .CheckAEq 0
        .POPN 6
    .EndGroup
    ; TEST stringFindChar
    .StartGroup "stringFindChar"
        rep #$10 ; 16b XY
        sep #$20 ; 8b A
        lda #'b'
        ldx #_teststr4
        jsl stringFindChar
        pha
        phx
        php
        .CheckXEq _teststr4
        plp
        plx
        pla
        inx
        jsl stringFindChar
        pha
        phx
        php
        .CheckXEq _teststr4+4
        plp
        plx
        pla
        inx
        jsl stringFindChar
        pha
        phx
        php
        .CheckXEq _teststr4+7
        plp
        plx
        pla
        inx
        jsl stringFindChar
        pha
        phx
        php
        .CheckXEq 0
        plp
        plx
        pla
        inx
    .EndGroup
    ; TEST stringLen
    .StartGroup "stringLen"
        rep #$10
        ldx #_teststrempty
        jsl stringLen
        .ACCU 16
        .CheckAEq 0
        rep #$10
        ldx #_teststr1
        jsl stringLen
        .ACCU 16
        .CheckAEq 7
        rep #$10
        ldx #_teststr22
        jsl stringLen
        .ACCU 16
        .CheckAEq 8
    .EndGroup
    ; TEST stringToU16
    .StartGroup "stringToU16"
        rep #$10
        ldx #_testnum_420
        jsl stringToU16
        .ACCU 16
        .CheckAEq 420
        rep #$10
        ldx #_testnum_32767
        jsl stringToU16
        .ACCU 16
        .CheckAEq 32767
        rep #$10
        ldx #_testnum_65535
        jsl stringToU16
        .ACCU 16
        .CheckAEq 65535
        rep #$10
        ldx #_testnum_0
        jsl stringToU16
        .ACCU 16
        .CheckAEq 0
    .EndGroup
    ; TEST stringToI16
    .StartGroup "stringToI16"
        rep #$10
        ldx #_testnum_420
        jsl stringToI16
        .ACCU 16
        .CheckAEq 420
        rep #$10
        ldx #_testnum_32767
        jsl stringToI16
        .ACCU 16
        .CheckAEq 32767
        rep #$10
        ldx #_testnum_0
        jsl stringToI16
        .ACCU 16
        .CheckAEq 0
        rep #$10
        ldx #_testnum_N0
        jsl stringToI16
        .ACCU 16
        .CheckAEq 0
        rep #$10
        ldx #_testnum_N420
        jsl stringToI16
        .ACCU 16
        .CheckAEq -420
        rep #$10
        ldx #_testnum_N32767
        jsl stringToI16
        .ACCU 16
        .CheckAEq -32767
        rep #$10
        ldx #_testnum_N32768
        jsl stringToI16
        .ACCU 16
        .CheckAEq -32768
    .EndGroup
    ; TEST writeU16
    .StartGroup "writeU16"
        rep #$30 ; 16b AXY
        tdc
        clc
        adc #$08
        sta.b $06 ; $06 = string buf
        tax ; X = D + 8
        lda #420
        jsl writeU16
        ldx.b $06
        ldy.w #_testnum_420
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #0
        jsl writeU16
        ldx.b $06
        ldy.w #_testnum_0
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #32767
        jsl writeU16
        ldx.b $06
        ldy.w #_testnum_32767
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #65535
        jsl writeU16
        ldx.b $06
        ldy.w #_testnum_65535
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
    .EndGroup
    ; TEST writeI16
    .StartGroup "writeI16"
        rep #$30 ; 16b AXY
        tdc
        clc
        adc #$08
        sta.b $06 ; $06 = string buf
        tax ; X = D + 8
        lda #420
        jsl writeI16
        ldx.b $06
        ldy.w #_testnum_420
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #0
        jsl writeI16
        ldx.b $06
        ldy.w #_testnum_0
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #32767
        jsl writeI16
        ldx.b $06
        ldy.w #_testnum_32767
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #-32767
        jsl writeI16
        ldx.b $06
        ldy.w #_testnum_N32767
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #-32768
        jsl writeI16
        ldx.b $06
        ldy.w #_testnum_N32768
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
        rep #$30 ; 16b AXY
        ldx.b $06
        lda #-420
        jsl writeI16
        ldx.b $06
        ldy.w #_testnum_N420
        jsl stringCmp
        .ACCU 8
        .CheckAEq 0
    .EndGroup
    .StartGroup "PathCheck"
        rep #$10
        ldx #loword(_test_invalid_path1)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 0
        ldx #loword(_test_invalid_path2)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 0
        ldx #loword(_test_invalid_path3)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 0
        ldx #loword(_test_valid_path1)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 1
        ldx #loword(_test_valid_path2)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 1
        ldx #loword(_test_valid_path3)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 1
        ldx #loword(_test_valid_path4)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 1
        ldx #loword(_test_valid_path5)
        jsl pathValidate
        .ACCU 8
        .CheckAEq 1
    .EndGroup
    .StartGroup "PathCmp"
        .PEAL _test_valid_path1_piece1
        .PEAL _test_valid_path1_piece1
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 6
        .PEAL _test_valid_path1_piece1
        .PEAL _test_valid_path1_piece2
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckANeq 0
        .POPN 6
        .PEAL _teststrempty
        .PEAL _test_valid_path1_piece2
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckANeq 0
        .POPN 6
        .PEAL _test_valid_path1_piece2
        .PEAL _teststrempty
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckANeq 0
        .POPN 6
        .PEAL _test_valid_path3+1
        .PEAL _test_valid_path3_piece1
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 6
        .PEAL _test_valid_path3+8
        .PEAL _test_valid_path3_piece2
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 6
        .PEAL _test_valid_path4
        .PEAL _test_valid_path4_piece1
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 6
        .PEAL _test_valid_path4+15
        .PEAL _test_valid_path4_piece2
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 6
        .PEAL _test_valid_path5
        .PEAL _test_valid_path5
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 6
    .EndGroup
    .StartGroup "PathRead"
        .PEAL _test_valid_path1
        .PEAL kTempBuffer
        jsl pathSplitIntoBuffer
        rep #$30
        lda #loword(kTempBuffer)
        sta $01,S
        .PEAL _test_valid_path1_piece1
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 3
        jsl pathSplitIntoBuffer
        rep #$30
        lda #loword(kTempBuffer)
        sta $01,S
        .PEAL _test_valid_path1_piece2
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 3
        jsl pathSplitIntoBuffer
        rep #$30
        lda #loword(kTempBuffer)
        sta $01,S
        .PEAL _test_valid_path1_piece3
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 3
        jsl pathSplitIntoBuffer
        rep #$30
        lda #loword(kTempBuffer)
        sta $01,S
        .PEAL _teststrempty
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        .CheckAEq 0
        .POPN 9
    .EndGroup
    .StartGroup "FS Device"
        phb
        .ChangeDataBank bankbyte(kfsDeviceStaticPath)
        ldx #loword(kfsDeviceStaticPath)
        jsl kfsFindDevicePointer
        .CheckYEq loword(kfsDeviceInstanceTable) + _sizeof_fs_device_instance_t
        rep #$30
        ldx #loword(kfsDeviceTempPath)
        jsl kfsFindDevicePointer
        .CheckYEq loword(kfsDeviceInstanceTable)
        rep #$30
        ldx #loword(kfsDeviceHomePath)
        jsl kfsFindDevicePointer
        .CheckYEq loword(kfsDeviceInstanceTable) + (_sizeof_fs_device_instance_t * 2)
        plb
        rep #$30
        ldx #loword(_teststr1)
        jsl kfsFindDevicePointer
        .CheckYEq 0
    .EndGroup
    .StartGroup "FS Open"
        ; ROM 1
        phb
        ldx #loword(_test_path_rom1)
        jsl fsOpen
        rep #$30
        txa
        plb
        .CheckANeq 0
        jsl fsClose
        ; ROM 2
        phb
        ldx #loword(_test_path_rom2)
        jsl fsOpen
        rep #$30
        txa
        plb
        .CheckANeq 0
        jsl fsClose
        ; ROM 3
        phb
        ldx #loword(_test_path_rom3)
        jsl fsOpen
        rep #$30
        txa
        plb
        .CheckANeq 0
        jsl fsClose
        ; INVALID 1
        phb
        ldx #loword(_test_path_rom_invalidfile1)
        jsl fsOpen
        rep #$30
        txa
        plb
        .CheckAEq 0
        jsl fsClose
        ; INVALID 2
        phb
        ldx #loword(_test_path_rom_invalidfile2)
        jsl fsOpen
        rep #$30
        txa
        plb
        .CheckAEq 0
        jsl fsClose
    .EndGroup

    jsl procExit

_errtxt: .db "ERROR\0"

.ENDS

.BANK $02 SLOT "ROM"
.SECTION "Test2" FREE

_alt_teststr1:
    .db "asdfbar\0"

_alt_teststr2:
    .db "asdffoo\0"

_alt_teststr22:
    .db "asdffooo\0"

_alt_teststr3:
    .db "qwertyuiop\0"

_alt_teststr4:
    .db "baaabaab\0"

_alt_testnum_0:
    .db "0\0"

_alt_testnum_420:
    .db "420\0"

_alt_testnum_32767:
    .db "32767\0"

_alt_testnum_65535:
    .db "65535\0"

_alt_testnum_N420:
    .db "-420\0"

_alt_testnum_N0:
    .db "-0\0"

_alt_testnum_N32767:
    .db "-32767\0"

_alt_testnum_N32768:
    .db "-32768\0"

_alt_teststrempty:
    .db "\0"

.ENDS