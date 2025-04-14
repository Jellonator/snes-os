.include "base.inc"

; Definitions for in-memory (RAM) filesystem device

.BANK $01 SLOT "ROM"
.SECTION "KFSMem" FREE

; $06,S: fs_device_instance_t* device
; B,Y: header
; $7E,X: device
_memfs_clear_device_instance:
    rep #$30
    lda #'M' | ('E' << 8)
    sta.w $0000,Y
    lda #'M' | (0 << 8)
    sta.w $0002,Y
; set up layout (copy 8 bytes)
    .REPT 4 INDEX i
        lda.l $7E0000 + fs_device_instance_t.data + (i*2),X
        sta.w $0004 + (i*2),Y
    .ENDR
; set up other data
    lda #1 ; first inode is header
    sta.w fs_memdev_root_t.num_used_inodes,Y
    lda.w fs_memdev_root_t.num_blocks_total,Y
    sta.w fs_memdev_root_t.num_total_inodes,Y
    dec A
    sta.w fs_memdev_root_t.num_free_inodes,Y
    tyx ; b,X is now used for header
; set up linked list
    ; first item
    sep #$20
    lda.w fs_memdev_root_t.bank_first,X
    xba
    lda.w fs_memdev_root_t.page_first,X
    rep #$20
    sta.w fs_memdev_root_t.inode_next_free,X
    ; iterate
    lda.w fs_memdev_root_t.page_first,X
    inc A
    xba
    and #$FF00
    sta.b kTmpPtrL
    sep #$20
    lda.w fs_memdev_root_t.bank_first,X
    sta.b kTmpPtrL+2
    @loop_bank:
        @loop_block:
            rep #$20
            ; TYPE = EMPTY
            lda #FS_INODE_TYPE_EMPTY
            ldy #fs_memdev_inode_t.type
            sta [kTmpPtrL],Y
            ; INODE_NEXT = NULL
            lda #0
            ldy #fs_memdev_inode_t.inode_next
            sta [kTmpPtrL],Y ; initialize inode_next to NULL; will be initialized in 'inc' code
            ; NLINK = 0
            ldy #fs_memdev_inode_t.nlink
            sta [kTmpPtrL],Y
            ; SIZE = 0
            ldy #fs_memdev_inode_t.size
            sta [kTmpPtrL],Y
            ldy #fs_memdev_inode_t.size+2
            sta [kTmpPtrL],Y
            ; check if last block
            sep #$20
            lda.b kTmpPtrL+1
            cmp.w fs_memdev_root_t.page_last,X
            beq @loop_block_end
            ; initialize inode_next of node
            rep #$20
            lda.b kTmpPtrL+1
            inc A
            sta [kTmpPtrL],Y
            ; increment pointer
            lda.b kTmpPtrL+1
            inc A
            sta.b kTmpPtrL+1
            jmp @loop_block
        @loop_block_end:
        ; check if last bank
        sep #$20
        lda.b kTmpPtrL+2
        cmp.w fs_memdev_root_t.bank_last,X
        beq @loop_bank_end
        ; initialize inode_next of node
        lda.b kTmpPtrL+2
        inc A
        xba
        lda.w fs_memdev_root_t.page_first,X
        rep #$20
        sta [kTmpPtrL],Y
        ; increment pointer
        lda.b kTmpPtrL+2
        inc A
        sta.b kTmpPtrL+2
        ; reset first page
        lda.w fs_memdev_root_t.page_first,X
        xba
        and #$FF00
        sta.b kTmpPtrL
        jmp @loop_bank
    @loop_bank_end:
    ; clear directory
    rep #$20
    lda #0
    sta.w fs_memdev_root_t.dirent.1.blockId,X
    rts

; $04,S: fs_device_instance_t* device
_memfs_init:
    phb
    rep #$30
    lda 1+$04,S
    tax
    ; set data bank to first bank
    sep #$20
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
    pha
    plb
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
    xba
    lda #0
    tay ; Y = first_bank:first_page:00
    ; check if magic number doesn't match
    rep #$20
    lda.w $0000,Y
    cmp #'M' | ('E' << 8)
    bne @magicnum_mismatch
    lda.w $0002,Y
    cmp #'M' | (0 << 8)
    bne @magicnum_mismatch
    jmp @magicnum_end
    @magicnum_mismatch:
        ; clear data
        jsr _memfs_clear_device_instance
    @magicnum_end:
    ; success
    plb
    rtl

_memfs_free:
    rtl

_memfs_lookup:
    rep #$30
    ldx #$1234
    rtl

_memfs_read:
    rtl

_memfs_write:
    rtl

.DSTRUCT KFS_DeviceType_Mem INSTANCEOF fs_device_template_t VALUES
    fsname .db "MEM\0"
    init   .dw _memfs_init
    lookup .dw _memfs_lookup
    read   .dw _memfs_read
    write  .dw _memfs_write
.ENDST

; _magicNum:
;     .db "FMD9"

; ; note: divide round up
; ; result = (x + n-1) / n

; ; Initialize Y directory entries at X
; kfsMemDirInit:
;     rep #$30 ; 16b AXY
;     bra @enter
; @loop:
;     txa
;     clc
;     adc #16
;     tax
; @enter:
;     stz.w $0000,X
;     dey
;     bne @loop
;     rtl

; ; Initialize memory device
; ; Push order:
; ;   bank   [db] $03
; ;   page   [db] $02
; ;   nbanks [db] $01, number of banks
; ;   npages [db] $00, number of pages per bank
; kfsMemInit:
;     sep #$20
;     .DisableInt__
;     phb
;     .DEFINE STK 6
;     .DEFINE P_BANK $03+STK
;     .DEFINE P_PAGE $02+STK
;     .DEFINE P_NBANK $01+STK
;     .DEFINE P_NPAGE $00+STK
;     ; data bank = p_bank
;     sep #$20
;     lda P_BANK,s
;     pha
;     plb
;     ; x = p_page * $0100
;     rep #$30
;     lda P_PAGE,s
;     xba
;     and #$FF00
;     tax
; ; begin
;     ; set magic number
;     lda.l _magicNum
;     sta.w fs_mem_header_t.magicnum,X
;     lda.l _magicNum+2
;     sta.w fs_mem_header_t.magicnum+2,X
;     ; set device and flags
;     lda #FS_DEVICE_SRAM
;     sta.w fs_mem_header_t.device,X ; flags = 0
;     ; set bank/block count
;     lda P_NBANK,s
;     and #$00FF
;     sta.w fs_mem_header_t.nBanks,X
;     sep #$20
;     sta.l MULTU_A
;     rep #$20
;     lda P_NPAGE,s
;     and #$00FF
;     sta.w fs_mem_header_t.nBlocksPerBank,X
;     sep #$20
;     sta.l MULTU_B
;     rep #$20
;     ; wait for multiplication to finish
;     ; set free mask and first inode indices
;     ; stz.w fs_mem_header_t.nUsedDataBLocks,X
;     stz.w fs_mem_header_t.nUsedInodeBlocks,X
;     stz.w fs_mem_header_t.nFreeMaskBlocks,X ; TODO: proper calculation
;     lda #1
;     sta.w fs_mem_header_t.firstInodeBlock,X
;     ; get nBlocks
;     lda.l MULTU_RESULT
;     sta.w fs_mem_header_t.nBlocks,X
;     ; nmaskbytes = (nblocks+8-1)/8
;     clc
;     adc #8-1
;     lsr
;     lsr
;     lsr
;     sta.w fs_mem_header_t.nFreeMaskBytes,X
;     ; nInodeBlocks = nBlocks / 4
;     lda.w fs_mem_header_t.nBlocks,X
;     lsr
;     lsr
;     sta.w fs_mem_header_t.nInodeBlocks,X
;     clc
;     adc.w fs_mem_header_t.nFreeMaskBlocks,X
;     inc A
;     sta.w fs_mem_header_t.firstDataBlock,X
;     lda.w fs_mem_header_t.nBlocks,X
;     sec
;     sbc.w fs_mem_header_t.firstDataBlock,X
;     sta.w fs_mem_header_t.nDataBlocks,X
;     ; set up root directory
;     phx
;     txa
;     clc
;     adc #fs_mem_header_t.rootDir
;     tax
;     ldy #10
;     jsl kfsMemDirInit
;     rep #$30 ; 16b AXY
;     plx
;     ; clear mask data
;     lda.w fs_mem_header_t.nFreeMaskBytes,X
;     inc A
;     lsr
;     phx
;     ; txy
;     @loop:
;         stz.w fs_mem_header_t.maskData,X
;         inx
;         inx
;         dec A
;         bne @loop
;     plx
;     sep #$20
;     lda #%00000001
;     sta.w fs_mem_header_t.maskData,X ; first bit set
; ; end
;     plb
;     .RestoreInt__
;     rtl
.ENDS
