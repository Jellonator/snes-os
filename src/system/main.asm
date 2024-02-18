.include "base.inc"

.BANK $00 SLOT "ROM"
.ORG $0000
.SECTION "KMainVectors" FORCE

; Called by SNES' IRQ timer.
; In charge of process switching.
kBrk__:
kIRQ__:
    sei
    rep #$20 ; 16b A
    pha
; disable interrupts
    sep #$20 ; 8b A
    lda #%00000001
    sta.l NMITIMEN
    lda.l TIMEUP
    jml kIRQ2__ ; go to FASTROM section

kEmptyHandler__:
    rti

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "MainCode" FREE

kIRQ2__:
; save context
    .ContextSave_NOA__
; begin
@entrypoint:
    sep #$30 ; 8b AXY
    .ChangeDataBank $7E
; find next READY process
    ldx.w loword(kCurrentPID)
    ; if current PID is not READY, change next PID to 1
    lda.w loword(kProcTabStatus),X
    cmp #PROCESS_READY
    beq +
        ldx #1
    +:
    lda.w loword(kQueueTabNext),X
; set found process to active
    sta.w loword(kCurrentPID)
; Switch to process
    asl
    tay
    rep #$10 ; 16b XY
    ldx.w loword(kProcTabStackSave),Y
    txs ; begin context switch
    pld
    plb
    ; rep #$10 ; 16b XY
    ply
    plx
    lda.l kNMITIMEN ; re-enable interrupts
    sta.l NMITIMEN
    rep #$20 ; 16b A
    pla ; finalize context switch
    rti

.ENDS

.SNESNATIVEVECTOR
    COP kEmptyHandler__
    BRK kBrk__
    ABORT kEmptyHandler__
    NMI kVBlank__
    IRQ kIRQ__
.ENDNATIVEVECTOR

.SNESEMUVECTOR
    COP kEmptyHandler__
    ABORT kEmptyHandler__
    NMI kEmptyHandler__
    RESET kInitialize__
    IRQBRK kEmptyHandler__
.ENDEMUVECTOR
