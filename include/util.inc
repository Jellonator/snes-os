; Maximum of A register and memory location, signed
.MACRO .AMAX
    cmp \1
    bpl @@@@@\.\@
    lda \1
@@@@@\.\@:
.ENDM

; Minimum of A register and memory location, signed
.MACRO .AMIN
    cmp \1
    bmi @@@@@\.\@
    lda \1
@@@@@\.\@:
.ENDM

; Maximum of A register and immediate value, signed
.MACRO .AMAXI
    cmp #\1
    bpl @@@@@\.\@
    lda #\1
@@@@@\.\@:
.ENDM

; Minimum of A register and immediate value, signed
.MACRO .AMINI
    cmp #\1
    bmi @@@@@\.\@
    lda #\1
@@@@@\.\@:
.ENDM

; Maximum of A register and memory location, unsigned
.MACRO .AMAXU
    cmp \1
    bcs @@@@@\.\@
    lda \1
@@@@@\.\@:
.ENDM

; Minimum of A register and memory location, unsigned
.MACRO .AMINU
    cmp \1
    bcc @@@@@\.\@
    lda \1
@@@@@\.\@:
.ENDM

; Maximum of A register and immediate value, unsigned
.MACRO .AMAXUI
    cmp #\1
    bcs @@@@@\.\@
    lda #\1
@@@@@\.\@:
.ENDM

; Minimum of A register and immediate value, unsigned
.MACRO .AMINUI
    cmp #\1
    bcc @@@@@\.\@
    lda #\1
@@@@@\.\@:
.ENDM

; Calculate the absolute value of A
; ONLY use after an instruction that loads the value into A (checks N flag)
; e.g.: ADC, SBC, DEC, INC, AND, ORA, EOR, ASL, LSR, ROL, ROR, LDA, PLA, TXA, and TYA
; some other instructions also set the N flag but may either refer to a
; different register (e.g. LDX), or don't reflect the current value of A (e.g. CMP)
.MACRO .ABS_A16_POSTLOAD
    bpl @@@@@\.\@
    eor #FFFF
    inc
@@@@@\.\@:
.ENDM

; Calculate the absolute value of A
; ONLY use after an instruction that loads the value into A (checks N flag)
.MACRO .ABS_A8_POSTLOAD
    bpl @@@@@\.\@
    eor #FF
    inc
@@@@@\.\@:
.ENDM

.define BYTES_PER_TILE16 32

.MACRO .BEGININTERRUPT
    phb
    phd
    rep #$30
    pha
    phx
    phy
.ENDM

.MACRO .ENDINTERRUPT
    rep #$30
    ply
    plx
    pla
    pld
    plb
.ENDM

.MACRO .ChangeDataBank ARGS bank
    pea bank + ($0100*(bank))
    plb
    plb
.ENDM

.MACRO .ClearWRam ARGS ADDRL, NBYTES
    rep #$20 ; 16 bit A
    lda #NBYTES
    sta DMA0_SIZE
    lda #loword(EmptyData)
    sta DMA0_SRCL
    lda #loword(ADDRL)
    sta WMADDL
    sep #$20 ; 8 bit A
    lda #bankbyte(EmptyData)
    sta DMA0_SRCH
    lda #bankbyte(ADDRL)
    sta WMADDH
    ; Absolute address, no increment, 1 byte at a time
    lda #%00001000
    sta DMA0_CTL
    ; Write to WRAM
    lda #$80
    sta DMA0_DEST
    lda #$01
    sta MDMAEN
.ENDM

.MACRO .ClearWRam_ZP ARGS ADDRL, NBYTES
    rep #$20 ; 16 bit A
    lda #NBYTES
    sta.b <DMA0_SIZE
    lda #loword(EmptyData)
    sta.b <DMA0_SRCL
    lda #loword(ADDRL)
    sta.l WMADDL
    sep #$20 ; 8 bit A
    lda #bankbyte(EmptyData)
    sta.b <DMA0_SRCH
    lda #bankbyte(ADDRL)
    sta.l WMADDH
    ; Absolute address, no increment, 1 byte at a time
    lda #%00001000
    sta.b <DMA0_CTL
    ; Write to WRAM
    lda #$80
    sta.b <DMA0_DEST
    lda #$01
    sta.l MDMAEN
.ENDM

.MACRO .ContextSave_NOA__
    rep #$30 ; 16b AXY
    phx
    phy
    phb
    phd
    lda.l kActiveProcessId
    and #$FF
    asl
    tay
    tsx
    txa
    tyx
    sta.l kProcessSPBackupTable,X
.ENDM

.MACRO .PushStack ARGS newstacksp
    rep #$10 ; 16b XY
    tsx
    txy
    ldx #newstacksp
    txs
    phy
.ENDM

.MACRO .RestoreStack
    rep #$10 ; 16b XY
    plx
    txs
.ENDM

.MACRO .ContextSave__
    rep #$30 ; 16b AXY
    pha
    .ContextSave_NOA__
.ENDM

; Disable IRQ/NMI, pushing value into stack
; A must be 8b
.MACRO .DisableInt__
    lda.l kNMITIMEN
    pha
    lda #1
    sta.l NMITIMEN ; disable NMI and IRQ, while keeping autojoypad on
    sta.l kNMITIMEN
.ENDM

; Restore IRQ/NMI mask stored in stack
; A must be 8b
.MACRO .RestoreInt__
    pla
    sta.l kNMITIMEN
    sta.l NMITIMEN
.ENDM

.MACRO .DCOLOR_RGB5 ARGS R, G, B
    .dw (B << 10) | (G << 5) | R
.ENDM
