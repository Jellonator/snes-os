.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "shps" FREE

_ps_state_tbl:
    .db '?'
    .db 'R'
    .db 'S'
    .db 'I'
    .db 'W'
    .ds 255-PROCESS_WAIT_NMI-1, '?'

_ps_txt:
    .db "PI S NAME\n"
    .db "-- - ----\n\0"
shPs_name: .db "ps\0"
shPs:
; write header
    phb
    .ChangeDataBank bankbyte(_ps_txt)
    rep #$30
    ldy #_ps_txt
    jsl kPutString
    plb
; allocate string
    pea 16
    jsl memAlloc
    rep #$30 ; 16b AXY
    pla
    cpx #0
    bne +
        jsl procExit
    +:
    stx.b $08 ; $08 is mem
; iterate processes
    ldx #1
@loop:
    stx.b $06 ; $06 is current pid
    lda.l kProcTabStatus,X
    and #$00FF
    bne +
        inx
        cpx #KPROC_NUM
        bcs @end
        bra @loop
+:
    lda.b $06
    ldx.b $08
    ; write PID
    sep #$20 ; 8b A, 16b XY
    jsl writePtr8
    lda #' '
    jsl writeChar
    rep #$20
    ; write string
    ldy.b $08
    jsl kPutString
    ; write state
    sep #$20
    lda #0
    xba
    ldx.b $06
    lda.l kProcTabStatus,X
    tax
    lda.l _ps_state_tbl,X
    jsl kPutC
    lda #' '
    jsl kPutC
    rep #$20
    ; write name
    phb
    ldx.b $06
    sep #$20
    lda.l kProcTabNameBank,X
    pha
    plb
    rep #$20
    txa
    asl
    tax
    lda.l kProcTabNamePtr,X
    tay
    jsl kPutString
    plb
    sep #$20
    lda #'\n'
    jsl kPutC
    rep #$30
    ; next PID
    ldx.b $06
    inx
    cpx #KPROC_NUM
    bcc @loop
@end:
    jsl procExit

.ENDS