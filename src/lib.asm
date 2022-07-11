.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "Lib" FREE

; compare A bytes between X and Y (A is 8b)
memcmp8:
    .ACCU 8
    cmp.b #0
    bne @loop
    rtl ; return if A == 0
@loop:
    xba ; we use top byte of accumulator as temp storage
    lda.w $0000,X
    cmp.w $0000,Y
    beq @continue
    bcc + 
    ; *X > *Y
    lda.b #$01 ; return A = -1
    rtl
    +:
    ; *X < *Y
    lda.b #$FF ; return A = 1
    rtl
@continue:
    inx
    iny
    xba
    dec A
    bne @loop
    rtl

; compare strings X and Y
strcmp:
    sep #$20 ; 8b A
    bra @loop
@continue:
    inx
    iny
@loop:
    lda.w $0000,X
    beq @xnull
    cmp.w $0000,Y
    beq @continue
    bcc +
    ; *X > *Y
    lda.b #$01 ; return A = 1
    rtl
    +:
    ; *X < *Y
    lda.b #$FF ; return A = -1
    rtl
@xnull: ; *X==0
    lda.w $0000,Y 
    beq + ; return A=0 if *Y=='\0', otherwise return A=-1 (*Y > '\0')
    lda.b #$FF
    +:
    rtl

; find first occurence of character A in X
; If character is found, X will be pointer to character
; otherwise, X will be NULL
; A must be 8b
strchr:
    .ACCU 8
    .INDEX 16
    cmp.w $0000,X
    bne +
    ; *X == A
    rtl
    +:
    ldy.w $0000,X
    bne +
    ; *X == '\0'
    ldx.w #0
    rtl
    +:
    inx
    bra strchr

; get length of string in X
; length is stored in A
strlen:
    .INDEX 16
    phx
    sep #$20 ; 8b A
    bra @enterloop
@continueloop:
    inx
@enterloop:
    lda.w $0000,X
    bne @continueloop
    rep #$20 ; 16b A
    txa
    sec
    sbc $01,s ; A = newX - oldX
    plx
    rtl

; transform string in X to 16b unsigned integer
; result is stored in A, X will point to character after last read digit
strtouw:
    .INDEX 16
    rep #$20
    lda.w #0
    pha
@loop:
    lda.w $0000,X
    and.w #$00FF
    .BranchIfDigit +
        ; character is not digit, return value
        pla
        rtl
    +:
    sec
    sbc #'0'
    sta.b $00
    lda $01,s
    asl
    asl
    clc
    adc $01,s
    asl
    adc.b $00
    sta $01,s
    inx
    bra @loop

; transform string in X to 16b signed integer
; result is stored in A, X will point to character after last read digit
strtoiw:
    .INDEX 16
    sep #$20
    lda.w $0000,X
    cmp #'-'
    beq @neg
    .BranchIfDigit @pos
        ; invalid
        lda.w #0
        rtl
    @neg:
        ; negative
        inx
        jsl strtouw
        .ACCU 16
        ; two's complement
        eor.w #$FFFF
        sec
        adc.w #0
        rtl
    @pos:
        jmp strtouw

_chtableupper:
    .DB "0123456789"
    .DB "ABCDEFGHIJ"
    .DB "KLMNOPQRST"
    .DB "UVWXYZ"
    .DSB (256-36-1), '?'
    .db '\0'

; write uint8 A to string X as pointer
; Afterwards, X will point to end of string
writeptrb
    .INDEX 16
    .ACCU 8
    pha
    lda #0
    xba ; make sure top byte is 0
    txy
    lda $01,s
    lsr
    lsr
    lsr
    lsr
    tax
    lda.l _chtableupper,X
    sta.w $0000,Y
    iny
    lda $01,s
    and #$0F
    tax
    lda.l _chtableupper,X
    sta.w $0000,Y
    iny
    tyx
    stz.w $0000,X
    pla
    rtl

; write uint16 A to string X as pointer
; Afterwards, X will point to end of string
writeptrw:
    .INDEX 16
    .ACCU 16
    pha
    txy
    ; first char
    and #$F000
    xba
    lsr
    lsr
    lsr
    lsr
    tax
    sep #$20
    lda.l _chtableupper,X
    sta.w $0000,Y
    iny
    ; second char
    lda $02,s
    and #$0F
    tax
    lda.l _chtableupper,X
    sta.w $0000,Y
    iny
    ; third char
    lda $01,s
    lsr
    lsr
    lsr
    lsr
    tax
    lda.l _chtableupper,X
    sta.w $0000,Y
    iny
    ; fourth char
    lda $01,s
    and #$0F
    tax
    lda.l _chtableupper,X
    sta.w $0000,Y
    iny
    tyx
    stz.w $0000,X
    rep #$20
    pla
    rtl

; write uint16 A to string X
; Afterwards, X will point to end of string (*X == '\0')
writeuw:
    .INDEX 16
    .ACCU 16
    ; special case: A==0
    cmp.w #0
    bne +
        lda.w #'0'
        sta.w $0000,X ; write "0\0" to *x
        inx
        rtl
    +:
    ; first: determine size of X,
    ; allocate space accordingly
    cmp.w #10
    bcc @d1
    cmp.w #100
    bcc @d2
    cmp.w #1000
    bcc @d3
    cmp.w #10000
    bcc @d4
; @d5:
    inx
@d4:
    inx
@d3:
    inx
@d2:
    inx
@d1:
    inx
; start
    phx
    txy
    sta.b $02
    sep #$20 ; 8b A
    .StartMul
    lda #$FF
    sta.b $00 ; character to write to X
    stz.b $01
    rep #$20 ; 16b A
    lda.b $02
    @loop:
    ; do {
    ;   digit = A % 10;
    ;   A = A / 10;
    ;   --X;
    ;   *X = '0' + digit;
    ; } while (A);
        sta.l DIVU_DIVIDEND
        sep #$20 ; 8b A
        lda.b #10
        sta.l DIVU_DIVISOR
    ; have to wait 16 cycles, so function can be made more
    ; efficient by packing instructions into this section
        ldx.b $00             ; 4
        lda.l _chtableupper,X ; 5
        sta.w $0000,Y         ; 5
        dey                   ; 2
        lda.l DIVU_REMAINDER ; 8b remainder
        sta.b $00
        rep #$20
        lda.l DIVU_QUOTIENT
        bne @loop
    ; write last (first?) character
    sep #$20
    ldx.b $00
    lda.l _chtableupper,X
    sta.w $0000,Y
; end
    .EndMul
    plx
    rtl

; write int16 A to string X
; Afterwards, X will point to end of string (*X == '\0')
writeiw:
    .INDEX 16
    .ACCU 16
    bit #$8000
    beq +
    pha
    lda #'-'
    sta.w $0000,X
    inx
    pla
    ; two's complement
    eor.w #$FFFF
    sec
    adc.w #0
    +:
    jmp writeuw

.ENDS