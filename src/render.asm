.include "base.inc"

.BANK $00 SLOT "ROM"
.SECTION "RenderInterrupt" FREE

KernelVBlank__:
    rep #$30
    lda.l RDNMI
    jml KernelVBlank2__

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "RenderCode" FREE

__EmptyData__:
    .dw 0

KernelVBlank2__:
    ; disable interrupts
    sep #$30
    .DisableInt__
    ; f-blank
    ; lda #%10001111
    ; sta.l INIDISP
    ; call update printer
    jsl KUpdatePrinter__
    ; stop f-blank
    ; lda #%00001111
    ; sta.l INIDISP
    ; re-enable interrupts
    sep #$30
    .RestoreInt__
    rti

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

.ENDS
