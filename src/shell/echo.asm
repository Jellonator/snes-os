.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shecho" FREE

_str_arg_path:
    .db "-o\0"

_str_space:
    .db " \0"

_err_invalid_argument:
    .db "Invalid argument\n\0"

_err_no_file_provided:
    .db "No file provided\n\0"

_err_could_not_open:
    .db "Could not open file\n\0"

_err_too_many_file:
    .db "Too many files provided\n\0"

_err_write_failed:
    .db "Write operation failed\n\0"

shEcho_name: .db "echo\0"
    ; $01,s: int argc
    ; $03,s: char **argv
    .DEFINE ARGS_TO_PARSE $08
    .DEFINE FILE_HANDLE $0A
    .DEFINE PARSE_CURRENT_ARGPTR $0C
    .DEFINE PARSE_CURRENT_ARGSTR $0E
    .DEFINE NUM_STRINGS $10
    .DEFINE STRINGS $12
shEcho:
; parse parameters
    rep #$30
    lda $01,s
    beql @end ; zero parameters, exit
    dec A
    beql @end ; one parameter (program name), exit
    sta.b ARGS_TO_PARSE
    stz.b FILE_HANDLE
    stz.b NUM_STRINGS
    ; allocate strings buffer
    lda.b $01,S
    asl
    pha
    jsl memAlloc
    stx.b STRINGS
    rep #$30
    pla
    ; loop parse parameters
    lda $03,S
    inc A
    inc A
    sta.b PARSE_CURRENT_ARGPTR
@loop_parse_args:
        rep #$30
        ldx.b PARSE_CURRENT_ARGPTR
        sep #$20
        ldy.w $0000,X
        sty.b PARSE_CURRENT_ARGSTR
        lda.w $0000,Y
        cmp #'-'
        bne +
            ; parse option
            jsr _parse_arg
            rep #$30
            jmp @loop_inc
        +:
        rep #$30
        ; not an option, copy pointer into list
        lda.b NUM_STRINGS
        asl
        tay
        lda.b PARSE_CURRENT_ARGSTR
        sta (STRINGS),Y
        inc.b NUM_STRINGS
        ; inc parameter
@loop_inc:
        inc.b PARSE_CURRENT_ARGPTR
        inc.b PARSE_CURRENT_ARGPTR
        dec.b ARGS_TO_PARSE
        beq @end_parse_args
        ; loop
        jmp @loop_parse_args
@end_parse_args:
; iterate strings, copying values into file
    .DEFINE CUR_STRING $08
    stz.b CUR_STRING
@loop_write_strings:
    lda.b CUR_STRING
    cmp.b NUM_STRINGS
    bcs @end_write_strings
    asl
    tay
    lda (STRINGS),Y
    tax
    ; write
    lda.b FILE_HANDLE
    beq @write_shell
    @write_file:
        ; write string
        phb
        phx
        jsl stringLen
        .ACCU 16
        .INDEX 16
        pha
        ldx.b FILE_HANDLE
        jsl fsWrite
        cmp #0
        beql _write_failed
        .POPN 5
        ; write space, if not last string
        rep #$30
        lda.b CUR_STRING
        inc A
        cmp.b NUM_STRINGS
        bcs @skip_write_space
            .PEAL _str_space
            pea 1
            ldx.b FILE_HANDLE
            jsl fsWrite
            cmp #0
            beql _write_failed
        @skip_write_space:
        jmp @write_end
    @write_shell:
        txy
        jsl kPutString
        sep #$20
        lda #' '
        jsl kPutC
    @write_end:
    rep #$30
    ; loop
    inc.b CUR_STRING
    jmp @loop_write_strings
@end_write_strings:
; close file
    ldx.b FILE_HANDLE
    beq +
        jsl fsClose
    +:
@end:
    ldx.b FILE_HANDLE
    bne +
        ; print newline if printing to screen
        sep #$20
        lda #'\n'
        jsl kPutC
    +:
    jsl procExit

_write_failed:
    ; print error
    .ChangeDataBank $01
    ldy #_err_write_failed
    jsl kPutString
    plb
    ; close file
    rep #$30
    ldx.b FILE_HANDLE
    beq +
        jsl fsClose
    +:
    ; exit
    jsl procExit

_parse_arg:
    phb
    ldx.b PARSE_CURRENT_ARGSTR
    phx
    .PEAL _str_arg_path
    jsl stringCmpL
    cmp #0
    beq @arg_output
    rep #$30
    ; error; exit
    .ChangeDataBank $01
    ldy #_err_invalid_argument
    jsl kPutString
    plb
    jsl procExit
@arg_output:
    .POPN 6
    jmp _parse_output

_parse_output:
    rep #$30
; increment arg pointer
    inc.b PARSE_CURRENT_ARGPTR
    inc.b PARSE_CURRENT_ARGPTR
    dec.b ARGS_TO_PARSE
    bne +
        ; error if no more args to parse
        .ChangeDataBank $01
        ldy #_err_no_file_provided
        jsl kPutString
        plb
        jsl procExit
    +:
    ldx.b PARSE_CURRENT_ARGPTR
    ldy.w $0000,X
    sty.b PARSE_CURRENT_ARGSTR
; check FILE_HANDLE is currently null
    lda.b FILE_HANDLE
    beq +
        phb
        .ChangeDataBank $01
        ldy #_err_too_many_file
        jsl kPutString
        plb
        jsl procExit
    +:
; try open file
    ldx.b PARSE_CURRENT_ARGSTR
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
    stx.b FILE_HANDLE
    rts

.ENDS