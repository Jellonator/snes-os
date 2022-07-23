.include "base.inc"

.BANK $00 SLOT "ROM"
.SECTION "RenderInterrupt" FREE

KernelVBlank__:
    sei
    rep #$20 ; 16b A
    pha
    ; disable interrupts
    sep #$20 ; 8b A
    lda #%00000001
    sta.l NMITIMEN
    ; Check if NMI is truely disabled
    ; There is a small window after writing to NMITIMEN where there is a chance
    ; that NMI will still activate, which can cause the kernel to hang.
    lda.l kNMITIMEN
    bit #$80
    bne +
        ; restore
        ; sta.l NMITIMEN
        rep #$20
        pla
        rti
    +:
    ; Deactivate NMI
    lda.l RDNMI
    ; Go to FASTROM section
    jml KernelVBlank2__

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "RenderCode" FREE

__EmptyData__:
    .dw 0

KRenderInit__:
    rep #$20
    lda #loword(KUpdatePrinter__)
    sta.l kRendererAddr
    lda #bankbyte(KUpdatePrinter__) | $0100
    sta.l kRendererAddr+2
    lda #$0000
    sta.l kRendererDP
    sep #$20
    lda #$7E
    sta.l kRendererDB
    rtl

KernelVBlank2__:
    ; save context
    .ContextSave_NOA__
    ; change to vblank stack
    .SetStack $007F
    ; f-blank
    sep #$20 ; 8b A
    lda #%10001111
    sta.l INIDISP
    ; call renderer
    lda.l kRendererDB
    pha
    plb
    rep #$20
    lda.l kRendererDP
    tcd
    .JSLAL loword(kRendererAddr)
    ; stop f-blank
    .ChangeDataBank $7E
    sep #$30 ; 8b AXY
    lda #%00001111
    sta.l INIDISP
    ; make waiting processes ready
@loop:
    ldx #KQID_NMILIST
    jsl kdequeue
    cpy #0
    beq @endloop
    lda #PROCESS_READY
    sta.w loword(kProcTabStatus),Y
    ldx #1
    jsl kenqueue
    bra @loop
@endloop:
; possibly more efficient method?
; would need to incorporate status change
;     ldx.w loword(kQueueTabNext) + KQID_NMILIST       ; X = next
;     cpx #KQID_NMILIST
;     beq @skiplist ; if nmilist->next == nmilist, skip
;         lda.w loword(kQueueTabPrev) + KQID_NMILIST   ; A = prev
;         sta.w $0001 ; $0001 = prev
;         ldy.w loword(kQueueTabNext) + KQID_READYLIST ; Y = readylist.next
;         sta.w loword(kQueueTabPrev),Y                ; qtPrev[readylist.next] = prev
;         stx.w loword(kQueueTabNext) + KQID_READYLIST ; qtNext[readylist] = next
;         lda #KQID_READYLIST                          ; A = readylist
;         sta.w loword(kQueueTabPrev),X                ; qtPrev[next] = readylist
;         tya                                          ; A = readylist.next
;         ldx.w $0001                                  ; X = prev
;         sta.w loword(kQueueTabNext),X                ; qtNext[prev] = readylist.next
;         lda #KQID_NMILIST
;         sta.w loword(kQueueTabNext) + KQID_NMILIST
;         sta.w loword(kQueueTabPrev) + KQID_NMILIST
; @skiplist:
    jsr KReadInput__
    ; Check if IRQ is disabled
    lda.l kNMITIMEN
    bit #$30
    bne +
        ; restore process
        rep #$30
        lda.w loword(kCurrentPID)
        and #$00FF
        asl
        tay
        ldx.w loword(kProcTabStackSave),Y
        txs
        pld
        plb
        ply
        plx
        lda.l kNMITIMEN ; re-enable interrupts
        sta.l NMITIMEN
        rep #$20 ; 16b A
        pla ; finalize context switch
        rti
    +:
    ; switch process
    jml KernelIRQ2__@entrypoint

KReadInput__:
    ; loop until controller allows itself to be read
    rep #$20 ; 8 bit A
@read_input_loop:
    lda.l HVBJOY
    and #$01
    bne @read_input_loop

    ; Read input
    rep #$30 ; 16 bit AXY
    lda.l kJoy1Raw
    tax
    lda.l JOY1INPUT
    sta.l kJoy1Raw
    txa
    eor.l kJoy1Raw
    and.l kJoy1Raw
    sta.l kJoy1Press
    txa
    and.l kJoy1Raw
    sta.l kJoy1Held
    ; Not worried about controller validity for now

    sep #$30 ; 8 bit AXY
    rts

; Copy palette to CGRAM
; PUSH order:
;   palette index  [db] $07
;   source bank    [db] $06
;   source address [dw] $04
; MUST call with jsl
KCopyPalette16:
    phb
    .ChangeDataBank $00
    rep #$20 ; 16 bit A
    lda 1+$04,s
    sta $4302 ; source address
    lda #32.w
    sta $4305 ; 32 bytes for palette
    sep #$20 ; 8 bit A
    lda 1+$06,s
    sta $4304 ; source bank
    lda 1+$07,s
    sta $2121 ; destination is first sprite palette
    stz $4300 ; write to PPU, absolute address, auto increment, 1 byte at a time
    lda #$22
    sta $4301 ; Write to CGRAM
    lda #$01
    sta $420B ; Begin transfer
    plb
    rtl

; Copy palette to CGRAM
; PUSH order:
;   palette index  [db] $07
;   source bank    [db] $06
;   source address [dw] $04
; MUST call with jsl
KCopyPalette4:
    phb
    .ChangeDataBank $00
    rep #$20 ; 16 bit A
    lda 1+$04,s
    sta $4302 ; source address
    lda #8.w
    sta $4305 ; 32 bytes for palette
    sep #$20 ; 8 bit A
    lda 1+$06,s
    sta $4304 ; source bank
    lda 1+$07,s
    sta $2121 ; destination is first sprite palette
    stz $4300 ; write to PPU, absolute address, auto increment, 1 byte at a time
    lda #$22
    sta $4301 ; Write to CGRAM
    lda #$01
    sta $420B ; Begin transfer
    plb
    rtl

; Copy data to VRAM
; Use this method if the sprite occupies an entire row in width,
; or it is only 1 tile in height.
; push order:
;   vram address   [dw] $09
;   num bytes      [dw] $07
;   source bank    [db] $06
;   source address [dw] $04
; MUST call with jsl
KCopyVMem:
    phb
    .ChangeDataBank $00
    rep #$20 ; 16 bit A
    lda 1+$07,s
    sta $4305 ; number of bytes
    lda 1+$04,s
    sta $4302 ; source address
    lda 1+$09,s
    sta $2116 ; VRAM address
    sep #$20 ; 8 bit A
    lda 1+$06,s
    sta $4304 ; source bank
    lda #$80
    sta $2115 ; VRAM address increment flags
    lda #$01
    sta $4300 ; write to PPU, absolute address, auto increment, 2 bytes at a time
    lda #$18
    sta $4301 ; Write to VRAM
    lda #$01
    sta $420B ; begin transfer
    plb
    rtl

; Clear a section of VRAM
; push order:
;   vram address [dw] $06
;   num bytes    [dw] $04
; MUST call with jsl
KClearVMem:
    phb
    .ChangeDataBank $00
    rep #$20 ; 16 bit A
    lda 1+$04,s
    sta DMA0_SIZE ; number of bytes
    lda #loword(__EmptyData__)
    sta DMA0_SRCL ; source address
    lda 1+$06,s
    sta $2116 ; VRAM address
    sep #$20 ; 8 bit A
    lda #bankbyte(__EmptyData__)
    sta DMA0_SRCH ; source bank
    lda #$80
    sta $2115 ; VRAM address increment flags
    lda #%00001001
    sta DMA0_CTL ; write to PPU, absolute address, no increment, 2 bytes at a time
    lda #$18
    sta DMA0_DEST ; Write to VRAM
    lda #$01
    sta MDMAEN ; begin transfer
    plb
    rtl

; Set renderer
;   address [dl] $04
KSetRenderer:
    rep #$20 ; 16b A
    tdc
    sta.l kRendererDP
    lda $04,s
    sta.l kRendererAddr
    sep #$20
    phb
    pla
    sta.l kRendererDB
    lda $06,s
    sta.l kRendererAddr+2
    lda.l kCurrentPID
    sta.l kRendererProcess
    rtl

.ENDS
