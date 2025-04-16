.include "base.inc"

; Definitions for in-memory (RAM) filesystem device

.BANK $01 SLOT "ROM"
.SECTION "KFSMem" FREE

; $06,S: fs_device_instance_t* device
; B,Y: header
; $7E,X: device
_memfs_clear_device_instance:
    rep #$30
    phd ; set up for use of direct page
    lda #$0000
    tcd
    lda #'M' | ('E' << 8)
    sta.w fs_memdev_root_t.magicnum+0,Y
    lda #'M' | (0 << 8)
    sta.w fs_memdev_root_t.magicnum+2,Y
; set up layout (copy 8 bytes)
    .REPT 4 INDEX i
        lda.l $7E0000 + fs_device_instance_t.data + (i*2),X
        sta.w fs_memdev_root_t.bank_first + (i*2),Y
    .ENDR
; set up other data
    lda #FS_INODE_TYPE_ROOT
    sta.w fs_memdev_root_t.type,Y
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
    pld
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
    lda.w fs_memdev_root_t.magicnum+0,Y
    cmp #'M' | ('E' << 8)
    bne @magicnum_mismatch
    lda.w fs_memdev_root_t.magicnum+2,Y
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

; [x16]inode *lookup([s16]fs_device_instance_t *dev, [s24]char *path);
; path: $04,S
; dev: $07,S
_memfs_lookup:
    ; check if path is empty; if so, then return root node
    phb
    rep #$30
    sep #$20
    lda 1+$06,S
    pha
    plb
    rep #$20
    lda 1+$04,S
    tax
    jsl pathIsEmpty
    .ACCU 8
    cmp #0
    beq @path_not_empty
        rep #$20
        lda 1+$07,S
        tax
        sep #$20
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
        xba
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
        rep #$20
        tax
        plb
        rtl
    @path_not_empty:
    plb
    phb
    rep #$30
    lda 1+$07,S
    tax
    ; get header
    sep #$20
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
    pha
    plb
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
    xba
    lda #0
    tay ; Y = first_bank:first_page:00
    ; search directory entries
    jmp @begin_search
    @loop_search:
        rep #$30
        ; next dirent
        tya
        clc
        adc #_sizeof_fs_memdev_direntry_t
        tay
        ; if we wrapped, then end search
        bit #$00FF
        bne @begin_search
        jmp @search_failed
    @begin_search:
        rep #$20
        lda.w fs_memdev_inode_t.dir.dirent.1.blockId,Y
        beql @search_failed
    ; compare paths
        phy
        ; directory path
        tya
        clc
        adc #fs_memdev_inode_t.dir.dirent.1.name
        phb
        pha
        ; check path
        sep #$20
        lda 6+$06,S
        pha
        rep #$20
        lda 7+$04,S
        pha
        ; do compare
        jsl pathPieceCmp
        rep #$30
        ply
        ply
        ply
        ply
        sep #$20
        cmp #0
        bne @loop_search
        ; name matched, check some stuff
        ; if NODE is FILE and TAIL(PATH) is EMPTY: return NODE
        ; if NODE is DIR and TAIL(PATH) is EMPTY: return NODE
        ; if NODE is FILE and TAIL(PATH) is VALID: FAIL
        ; if NODE is DIR and TAIL(PATH) is VALID: search NODE
        ; PATH = TAIL(PATH)
        rep #$20
        lda 1+$04,S
        tax
        sep #$20
        lda 1+$06,S
        phb
        pha
        plb
        jsl pathGetTailPtr
        rep #$20
        txa
        sta 2+$04,S
        ; calculate if path is empty
        jsl pathIsEmpty
        sep #$20
        plb ; restore bank
        cmp #0
        bne @tail_is_empty
        ; VALID TAIL
            ; swap context to inode
            lda #0
            xba
            lda.w fs_memdev_inode_t.dir.dirent.1.blockId,Y
            xba
            tax
            lda.w fs_memdev_inode_t.dir.dirent.1.blockId+1,Y
            pha
            plb
            txy
            ; check type
            rep #$20
            lda.w fs_memdev_inode_t.type,Y
            cmp #FS_INODE_TYPE_DIR
            beq @begin_search
            jmp @search_failed
        @tail_is_empty:
        ; EMPTY TAIL
            .ACCU 8
            .INDEX 16
            ; swap context to inode
            lda #0
            xba
            lda.w fs_memdev_inode_t.dir.dirent.1.blockId,Y
            xba
            tax
            lda.w fs_memdev_inode_t.dir.dirent.1.blockId+1,Y
            pha
            plb
            txy
            ; check type
            rep #$20
            lda.w fs_memdev_inode_t.type,Y
            ; cmp #FS_INODE_TYPE_FILE
            ; beq @found_inode
            ;     jmp @search_failed
            @found_inode:
                txa
                sep #$20
                phb
                pla
                xba
                plb
                rep #$20
                tax
                rtl
    ; end
@search_failed:
    rep #$30
    plb
    ldx #0
    rtl

; [a16]u16 read([s16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; fh:     $09,S
; buffer: $06,S
; nbytes: $04,S
_memfs_read:
    ; TODO: implement indirect blocks
    .DEFINE BYTES_TO_READ kTmpBuffer
    rep #$30
    lda $04,S
    bne @has_bytes
        lda #0
        rtl
@has_bytes:
    ; switch direct page
    phd ; [+2, 2]
    lda #$0000
    tcd
    ; put inode ptr
    lda 2+$09,S
    tax
    lda.l $7E0000 + fs_handle_instance_t.inode,X
    stz.b kTmpPtrL
    sta.b kTmpPtrL+1
    ; put buffer ptr
    lda 2+$06,S
    sta.b kTmpPtrL2
    lda 2+$08,S
    sta.b kTmpPtrL2+2
    ; check type
    ldy #fs_memdev_inode_t.type
    lda [kTmpPtrL],Y
    cmp #FS_INODE_TYPE_FILE
    beq +
        ; read directory (or root as if it were a directory)
        cmp #FS_INODE_TYPE_DIR
        beql _memfs_read_dir
        cmp #FS_INODE_TYPE_ROOT
        beql _memfs_read_dir
        ; not either, don't read anything
        lda #0
        rtl
    +:
    ; check size
    lda 2+$04,S
    sta.b BYTES_TO_READ
    ldy #fs_memdev_inode_t.size
    lda [kTmpPtrL],Y
    sec
    sbc.l $7E0000 + fs_handle_instance_t.fileptr,X
    .AMINU P_DIR BYTES_TO_READ
    sta.b BYTES_TO_READ
    cmp #0
    bne +
        pld
        lda #0
        rtl
    +:
    ; inc inode to directData + fileptr
    lda.b kTmpPtrL
    clc
    adc #fs_memdev_inode_t.file.directData
    clc
    adc.l $7E0000 + fs_handle_instance_t.fileptr,X
    sta.b kTmpPtrL
    ; copy bytes
    sep #$20
    ldy #0
    ldx.b BYTES_TO_READ
    @loop_copy:
        lda [kTmpPtrL],Y
        sta [kTmpPtrL2],Y
        iny
        dex
        bne @loop_copy
    ; update fileptr
    rep #$20
    lda 2+$09,S
    tax
    lda.l $7E0000 + fs_handle_instance_t.fileptr,X
    clc
    adc.b BYTES_TO_READ
    sta.l $7E0000 + fs_handle_instance_t.fileptr,X
    ; end
    lda.b BYTES_TO_READ
    pld ; [-2, 0]
    rtl

; read from directory as if it were a file;
; file names will be separated by null separators.
; continuation of _memfs_read
_memfs_read_dir:
    .ACCU 16
    .INDEX 16
    .DEFINE BYTES_READ (kTmpBuffer+2)
    .DEFINE FILEPTR (kTmpBuffer+4)
    ; check size
    lda 2+$04,S
    sta.b BYTES_TO_READ
    lda.l $7E0000 + fs_handle_instance_t.fileptr,X
    sta.b FILEPTR
    stz.b BYTES_READ
    ; inc inode to directData+fileptr
    lda.b kTmpPtrL
    clc
    adc #fs_memdev_inode_t.dir.dirent
    clc
    adc.l $7E0000 + fs_handle_instance_t.fileptr,X
    sta.b kTmpPtrL
    ldy #2
    ; copy bytes
    jmp @loop_copy_begin
    @loop_copy:
        ; decrement bytes to read, and end if no more bytes can be read
        dec.b BYTES_TO_READ
        inc.b BYTES_READ
        beq @loop_copy_end
    @loop_copy_begin:
        ; if fileptr%16 == 14, then read in a null byte and increment.
        ; this only comes into play with 14b long file names, but it must
        ; be handled regardless.
        ; also, exit loop if inode is null
        lda.b FILEPTR
        and #$000F
        cmp #14
        bne @loop_copy_not_eol
            lda [kTmpPtrL],Y
            cmp #0
            beq @loop_copy_end
            inc.b FILEPTR
            inc.b FILEPTR
            inc.b kTmpPtrL
            inc.b kTmpPtrL
            sep #$20
            lda #'\n'
            sta [kTmpPtrL2]
            rep #$20
            inc.b kTmpPtrL2
            jmp @loop_copy
        ; if fileptr%16 == 0, then end if inode is null, or fileptr >= 14*16
    @loop_copy_not_eol:
        cmp #14*16
        bcs @loop_copy_end
        cmp #0
        bne @loop_copy_not_null
            lda [kTmpPtrL]
            cmp #0
            beq @loop_copy_end
            ; jmp @loop_copy
    @loop_copy_not_null:
        sep #$20
        lda [kTmpPtrL],Y
        cmp #0
        bne +
            lda #'\n'
            sta [kTmpPtrL2]
            rep #$20
            inc.b kTmpPtrL
            inc.b kTmpPtrL2
            inc.b FILEPTR
            jmp @loop_copy_loop_inc
        +:
        sta [kTmpPtrL2]
        rep #$20
        inc.b kTmpPtrL
        inc.b kTmpPtrL2
        inc.b FILEPTR
        jmp @loop_copy
        ; if byte was null, skip until (fileptr%16) is 0
        @loop_copy_loop_inc:
            lda.b FILEPTR
            bit #$000F
            beq @loop_copy
            inc.b FILEPTR
            inc.b kTmpPtrL
            jmp @loop_copy_loop_inc
    @loop_copy_end:
    ; update fileptr
    rep #$20
    lda 2+$09,S
    tax
    lda.b FILEPTR
    sta.l $7E0000 + fs_handle_instance_t.fileptr,X
    ; end
    lda.b BYTES_READ
    pld ; [-2, 0]
    rtl
    .UNDEFINE BYTES_TO_READ

_memfs_write:
    rtl

.DSTRUCT KFS_DeviceType_Mem INSTANCEOF fs_device_template_t VALUES
    fsname .db "MEM\0"
    init   .dw _memfs_init
    lookup .dw _memfs_lookup
    read   .dw _memfs_read
    write  .dw _memfs_write
.ENDST

.ENDS
