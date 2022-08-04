.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "FSMem" FREE

_magicNum:
    .db "FMD9"

; note: divide round up
; result = (x + n-1) / n

; Initialize Y directory entries at X
kfsMemDirInit:
    rep #$30 ; 16b AXY
    bra @enter
@loop:
    txa
    clc
    adc #16
    tax
@enter:
    stz.w $0000,X
    dey
    bne @loop
    rtl

; Initialize memory device
; Push order:
;   bank   [db] $03
;   page   [db] $02
;   nbanks [db] $01, number of banks
;   npages [db] $00, number of pages per bank
kfsMemInit:
    sep #$20
    .DisableInt__
    phb
    .DEFINE STK 6
    .DEFINE P_BANK $03+STK
    .DEFINE P_PAGE $02+STK
    .DEFINE P_NBANK $01+STK
    .DEFINE P_NPAGE $00+STK
    ; data bank = p_bank
    sep #$20
    lda P_BANK,s
    pha
    plb
    ; x = p_page * $0100
    rep #$30
    lda P_PAGE,s
    xba
    and #$FF00
    tax
; begin
    ; set magic number
    lda.l _magicNum
    sta.w fs_mem_header_t.magicnum,X
    lda.l _magicNum+2
    sta.w fs_mem_header_t.magicnum+2,X
    ; set device and flags
    lda #FS_DEVICE_SRAM
    sta.w fs_mem_header_t.device,X ; flags = 0
    ; set bank/block count
    lda P_NBANK,s
    and #$00FF
    sta.w fs_mem_header_t.nBanks,X
    sep #$20
    sta.l MULTU_A
    rep #$20
    lda P_NPAGE,s
    and #$00FF
    sta.w fs_mem_header_t.nBlocksPerBank,X
    sep #$20
    sta.l MULTU_B
    rep #$20
    ; wait for multiplication to finish
    ; set free mask and first inode indices
    stz.w fs_mem_header_t.nUsedDataBLocks,X
    stz.w fs_mem_header_t.nUsedInodeBlocks,X
    stz.w fs_mem_header_t.nFreeMaskBlocks,X ; TODO: proper calculation
    lda #1
    sta.w fs_mem_header_t.firstInodeBlock,X
    ; get nBlocks
    lda.l MULTU_RESULT
    sta.w fs_mem_header_t.nBlocks,X
    ; nmaskbytes = (nblocks+8-1)/8
    clc
    adc #8-1
    lsr
    lsr
    lsr
    sta.w fs_mem_header_t.nFreeMaskBytes,X
    ; nInodeBlocks = nBlocks / 4
    lda.w fs_mem_header_t.nBlocks,X
    lsr
    lsr
    sta.w fs_mem_header_t.nInodeBlocks,X
    clc
    adc.w fs_mem_header_t.nFreeMaskBlocks,X
    inc A
    sta.w fs_mem_header_t.firstDataBlock,X
    lda.w fs_mem_header_t.nBlocks,X
    sec
    sbc.w fs_mem_header_t.firstDataBlock,X
    sta.w fs_mem_header_t.nDataBlocks,X
    ; set up root directory
    phx
    txa
    clc
    adc #fs_mem_header_t.rootDir
    tax
    ldy #10
    jsl kfsMemDirInit
    rep #$30 ; 16b AXY
    plx
    ; clear mask data
    lda.w fs_mem_header_t.nFreeMaskBytes,X
    inc A
    lsr
    phx
    ; txy
    @loop:
        stz.w fs_mem_header_t.maskData,X
        inx
        inx
        dec A
        bne @loop
    plx
    sep #$20
    lda #%00000001
    sta.w fs_mem_header_t.maskData,X ; first bit set
; end
    plb
    .RestoreInt__
    rtl
.ENDS
