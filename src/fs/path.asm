.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "Path" FREE

; Return true if string in X is an absolute path
pathIsAbsolute:
    .INDEX 16
    sep #$20
    lda.w $0000,X
    cmp #'/'
    beq +
        lda #0
        rtl ; False - first char is '/'
    +:
    lda #1
    rtl ; True - first char is not '/'

; Return true if string in X is a relative path
pathIsRelative:
    .INDEX 16
    sep #$20
    lda.w $0000,X
    cmp #'/'
    beq +
        lda #1
        rtl ; True - first char is '/'
    +:
    lda #0
    rtl ; False - first char is not '/'

; Return true if string in X is empty
pathIsEmpty:
    .INDEX 16
    sep #$20
    lda.w $0000,X
    beq +
        lda #0
        rtl ; False - first char not null
    +:
    lda #1
    rtl ; True - first char is null

; Get pointer to tail of X
pathGetTailPtr:
    .INDEX 16
    sep #$20
    lda.w $0000,X
    cmp #0
    beq @end_no_inx ; already reached null, just end
    cmp #'/'
    bne +
        inx ; skip first '/'
    +:
    ; skip until null or /
@loop:
    lda.w $0000,X
    cmp #'/'
    beq @end_with_inx
    cmp #0
    beq @end_no_inx
    inx
    jmp @loop
@end_with_inx:
    inx
@end_no_inx:
    rtl

; Validates path in X
; Returns with A=0 if invalid, or A=1 if valid
pathValidate:
    .INDEX 16
    sep #$20
    phx ; [+2; 2]
    lda.w $0000,X
    cmp #0
    bne +
        ; empty string, return 0
        lda #0
        plx
        rtl
    +:
    cmp #'/'
    bne +
        inx
    +:
    ldy #0
    ; check up to 'FS_MAX_FILENAME_LEN' characters
@loop:
    lda.w $0000,X
    ; cmp #0 (commented out - not necessary after lda)
    bne +
        ; reached null; success
        lda #1
        plx
        rtl
    +:
    cmp #'/'
    bne +
        ; reached /, fail if Y=0
        cpy #0
        bne ++
            lda #0
            plx
            rtl
        ++:
        ; otherwise, parse next block
        inx
        ldy #0
        jmp @loop
    +:
    ; found a character
    cpy #FS_MAX_FILENAME_LEN
    bne +
        ; too many characters in part, fail
        lda #0
        plx
        rtl
    +:
    iny
    inx
    jmp @loop

; Compare two paths pieces in separate buffers
; Push order:
; str1 [dl], $07
; str2 [dl], $04
; This is similar to `stringCmpL`, except:
;  * we only check up to 14 characters
;  * '/' is treated as a null
pathPieceCmp:
    rep #$30
    tsc ; A = SP
    phd ; Push DP
    tcd ; DP = previous SP
    sep #$20 ; 8B A, 16B XY
    ldy #0 ; Y = 0
    ldx #FS_MAX_FILENAME_LEN ; X = LEN
    bra @loop
@continue:
    iny
    dex
    bne +
        ; reached max path piece length, must be null
        pld
        lda.b #0
        rtl
    +:
@loop:
    lda.b [$07],Y
    beq @xnull
    cmp #'/'
    beq @xnull
    cmp.b [$04],Y
    beq @continue
    ; very slight difference here;
    ; "abc." < "abc/", but "abc." > "abc"
    bcc +
        pld
        lda.b #$01
        rtl
    +:
        pld
        lda.b #$FF
        rtl
@xnull:
    lda.b [$04],Y
    bne +
        pld
        lda #0
        rtl
    +:
    cmp #'/'
    bne +
        pld
        lda #0
        rtl
    +:
    pld
    lda.b #$FF
    rtl

; Reads next piece from path
; Push order:
; src  [dl], $07
; dest [dl], $04
; `dest` should be at least FS_MAX_FILENAME_LEN+1 bytes
; `src` will be incremented to the end of the piece
; `dest` will be incremented to the end of the string (nullptr)
pathSplitIntoBuffer:
    rep #$30
    tsc ; A = SP
    phd ; Push DP
    tcd ; DP = previous SP
    sep #$20 ; 8B A, 16B XY
    ; if *src == '/':
    lda.b [$07]
    cmp #'/'
    bne +
        ; ++ src
        inc.b $07
        lda.b [$07]
    +:
    ldx #FS_MAX_FILENAME_LEN
    ; do {
@loop:
    ; if (*src == '/' || *src == '\0') goto @finish
    cmp #'/'
    beq @finish
    cmp #0
    beq @finish
    ; *dest = *src
    sta.b [$04]
    ; ++ dest
    inc.b $04
    ; ++ src
    inc.b $07
    ; } while (--x != 0)
    dex
    beq @finish
    lda.b [$07]
    jmp @loop
@finish:
    ; *dest = '\0'
    lda #0
    sta.b [$04]
    ; return
    pld
    rtl

.ENDS