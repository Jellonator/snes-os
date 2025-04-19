.include "base.inc"

; Definitions for in-memory (RAM) filesystem device

.BANK $01 SLOT "ROM"
.SECTION "KFSMem" FREE

; Clear directory stored in X
_clear_dir:
    rep #$20
    lda #0
    .REPT FSMEM_DIR_MAX_INODE_COUNT INDEX i
        sta.w fs_memdev_root_t.dirent.{i+1}.blockId,X
    .ENDR
    rts

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
    inc A
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
            ldy #fs_memdev_inode_t.inode_next
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
        ldy #fs_memdev_inode_t.inode_next
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
    jsr _clear_dir
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
    .DEFINE PARENT_NODE $00
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
        ldy #0 ; root has no parent
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
    sta.b PARENT_NODE+1
    pha
    plb
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
    sta.b PARENT_NODE
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
            sta.b PARENT_NODE
            xba
            tax
            lda.w fs_memdev_inode_t.dir.dirent.1.blockId+1,Y
            sta.b PARENT_NODE+1
            pha
            plb
            txy
            ; check type
            rep #$20
            lda.w fs_memdev_inode_t.type,Y
            cmp #FS_INODE_TYPE_DIR
            beq @begin_search
            stz.b PARENT_NODE ; PARENT_NODE is set to NULL, since it is not a DIR
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
                ldy.b PARENT_NODE
                rtl
    ; end
@search_failed:
    rep #$30
    plb
    ; failed - no node, no parent
    ldx #0
    ldy.b PARENT_NODE
    rtl
    .UNDEFINE PARENT_NODE

; [a16]u16 read([s16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; fh:     $09,S
; buffer: $06,S
; nbytes: $04,S
_memfs_read:
    ; TODO: implement indirect blocks
    .DEFINE BYTES_TO_READ kTmpBuffer
    .DEFINE BYTES_LEFT (kTmpBuffer+2)
    .DEFINE DIRECTBLOCK_DATA_PTR (kTmpBuffer+4)
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
        pld
        lda #0
        rtl
    +:
    ; check size
    lda 2+$04,S
    sta.b BYTES_TO_READ
    ldy #fs_memdev_inode_t.size
    lda [kTmpPtrL],Y
    sec
    ; TODO: fail if fileptr is invalid?
    sbc.l $7E0000 + fs_handle_instance_t.fileptr,X
    .AMINU P_DIR BYTES_TO_READ
    sta.b BYTES_TO_READ
    cmp #0
    bne +
        pld
        lda #0
        rtl
    +:
    lda.b BYTES_TO_READ
    sta.b BYTES_LEFT
    ; set Y to pointer of data
    lda.l $7E0000 + fs_handle_instance_t.fileptr,X
    clc
    adc #fs_memdev_inode_t.file.directData
    tay
    sep #$20
    @loop_copy:
        cpy #256 ; if Y reaches past end of direct data, switch to direct blocks
        bcs @begin_directblock_data_read
        lda [kTmpPtrL],Y
        sta [kTmpPtrL2]
        inc.b kTmpPtrL2
        dec.b BYTES_LEFT
        beq @end_read
        iny
        jmp @loop_copy
; start reading of direct data
@begin_directblock_data_read:
    ; Y should be current data pointer+64, so (y/256)-1 is direct data pointer
    ; Get direct data index
    rep #$30
    tyx
    tya
    xba
    and #$00FF
    dec A
    asl
    ; get direct data pointer
    clc
    adc #fs_memdev_inode_t.file.directBlocks
    tay
    ; write direct data pointer
    lda [kTmpPtrL],Y
    stz.b DIRECTBLOCK_DATA_PTR
    sta.b DIRECTBLOCK_DATA_PTR+1
    ; set Y to local index
    txa
    and #$00FF
    tay
@loop_directblock_copy:
        cpy #256
        bcs @next_directblock
        lda [DIRECTBLOCK_DATA_PTR],Y
        sta [kTmpPtrL2]
        inc.b kTmpPtrL2
        dec.b BYTES_LEFT
        beq @end_read
        iny
        jmp @loop_directblock_copy
@next_directblock:
        txa
        and #$FF00
        xba
        inc A
        xba
        tay
        jmp @begin_directblock_data_read
; end read operation
@end_read:
    ; update fileptr
    rep #$30
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
    ; TODO: fail if fileptr is invalid
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
        inc.b BYTES_READ
        dec.b BYTES_TO_READ
        beq @loop_copy_end
    @loop_copy_begin:
        ; if fileptr%16 == 14, then read in a null byte and increment.
        ; this only comes into play with 14b long file names, but it must
        ; be handled regardless.
        ; also, exit loop if inode is null
        lda.b FILEPTR
        and #FSMEM_DIR_INODESIZE-1
        cmp #FS_MAX_FILENAME_LEN
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
        cmp #FSMEM_DIR_INODESIZE*FSMEM_DIR_MAX_INODE_COUNT
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
    .UNDEFINE BYTES_LEFT
    .UNDEFINE DIRECTBLOCK_DATA_PTR
    .UNDEFINE BYTES_READ
    .UNDEFINE FILEPTR

; Write data from buffer into file
; [a16]u16 write([s16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; nbytes $04,S
; buffer $06,S
; fh     $09,S
_memfs_write:
    ; TODO: write to fileptr, only increment SIZE if fileptr
    ; eaches past end of file
    .DEFINE SOURCE kTmpPtrL
    .DEFINE DEST kTmpPtrL2
    .DEFINE BYTES_TO_WRITE kTmpBuffer
    .DEFINE BYTES_TO_WRITE_IN_BLOCK (kTmpBuffer+2)
    .DEFINE INITIAL_SIZE (kTmpBuffer+4)
    ; .DEFINE TOTAL_BYTES_WRITTEN (kTmpBuffer+6)
    .DEFINE ROOT_PTR (kTmpBuffer+8)
    .DEFINE DIRECT_PTR (kTmpBuffer+11)
    .DEFINE DIRECT_INDEX (kTmpBuffer+14)
    rep #$30
; check nbytes > 0
    lda $04,S
    bne @has_bytes
        lda #0
        rtl
@has_bytes:
    phd
    lda #$0000
    tcd
; get dest ptr
    lda 2+$09,S
    tax
    stz.b DEST
    lda.l $7E0000 + fs_handle_instance_t.inode,X
    sta.b DEST+1
; get source ptr
    lda 2+$06,S
    sta.b SOURCE
    lda 2+$07,S
    sta.b SOURCE+1
; determine total number of bytes to write.
; can store 192B (direct) + 4KiB (direct block)
    ldy #fs_memdev_inode_t.size
    lda [DEST],Y
    sta.b INITIAL_SIZE
    lda #192 + 16 * 256
    sec
    sbc [DEST],Y
    .AMINU P_STACK 2+$04
    sta.b BYTES_TO_WRITE
    cmp #0
    beql @end_writing_bytes
; write bytes
    ; first, determine WHERE to write
    ldy #fs_memdev_inode_t.size
    lda [DEST],Y
    cmp #192
    bcsl @do_write_directblock
    ; write to node's direct data
        ; determine number of bytes to write in block
        lda #192
        sec
        sbc [DEST],Y
        .AMINU P_DIR BYTES_TO_WRITE
        tax
        sta.b BYTES_TO_WRITE_IN_BLOCK
        ; get destination pointer
        lda [DEST],Y
        clc
        adc #fs_memdev_inode_t.file.directData
        tay
    @loop_direct_write:
            ; copy byte
            sep #$20
            lda [SOURCE]
            sta [DEST],Y
            rep #$20
            ; iter
            inc.b SOURCE
            iny
            dex
            bne @loop_direct_write
        ; subtract bytes and add to size
        ldy #fs_memdev_inode_t.size
        lda [DEST],Y
        clc
        adc.b BYTES_TO_WRITE_IN_BLOCK
        sta [DEST],Y
        lda.b BYTES_TO_WRITE
        sec
        sbc.b BYTES_TO_WRITE_IN_BLOCK
        sta.b BYTES_TO_WRITE
        beql @end_writing_bytes
@do_write_directblock:
    ; first, allocate new direct block if (size - 192) % 256 == 0
    ldy #fs_memdev_inode_t.size
    lda [DEST],Y
    sec
    sbc #192
    xba
    and #$00FF
    asl
    clc
    adc #fs_memdev_inode_t.file.directBlocks
    sta.b DIRECT_INDEX
    lda [DEST],Y
    sec
    sbc #192
    and #$00FF
    bne @dont_allocate_direct
        ; allocate a direct block
        lda 2+$09,S
        tax
        lda.l $7E0000 + fs_handle_instance_t.device,X
        tax
        sep #$20
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
        sta.b ROOT_PTR+2
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
        sta.b ROOT_PTR+1
        stz.b ROOT_PTR
        rep #$20
        ; DIRECT = ROOT->next
        ldy #fs_memdev_root_t.inode_next_free
        lda [ROOT_PTR],Y
        stz.b DIRECT_PTR
        sta.b DIRECT_PTR+1
        ; ROOT->next = ROOT->next->next
        ldy #fs_memdev_inode_t.inode_next
        lda [DIRECT_PTR],Y
        ldy #fs_memdev_root_t.inode_next_free
        sta [ROOT_PTR],Y
        ; modify root available nodes
        ldy #fs_memdev_root_t.num_used_inodes
        lda [ROOT_PTR],Y
        inc A
        sta [ROOT_PTR],Y
        ldy #fs_memdev_root_t.num_free_inodes
        lda [ROOT_PTR],Y
        dec A
        sta [ROOT_PTR],Y
        ldy.b DIRECT_INDEX
        lda.b DIRECT_PTR+1
        sta [DEST],Y
        jmp @allocated_direct
@dont_allocate_direct:
        ldy.b DIRECT_INDEX
        stz.b DIRECT_PTR
        lda [DEST],Y
        sta.b DIRECT_PTR+1
@allocated_direct:
        ; determine number of bytes to write in block
        ldy #fs_memdev_inode_t.size
        ; get dest pointer
        lda [DEST],Y
        sec
        sbc #192
        and #$00FF
        tay
        ; determine number of bytes to write
        sta.b BYTES_TO_WRITE_IN_BLOCK
        lda #256
        sec
        sbc.b BYTES_TO_WRITE_IN_BLOCK
        .AMINU P_DIR BYTES_TO_WRITE
        tax
        sta.b BYTES_TO_WRITE_IN_BLOCK
    @loop_directblock_write:
            ; copy byte
            sep #$20
            lda [SOURCE]
            sta [DIRECT_PTR],Y
            rep #$20
            ; iter
            inc.b SOURCE
            iny
            dex
            bne @loop_directblock_write
        ; subtract bytes and add to size
        ldy #fs_memdev_inode_t.size
        lda [DEST],Y
        clc
        adc.b BYTES_TO_WRITE_IN_BLOCK
        sta [DEST],Y
        lda.b BYTES_TO_WRITE
        sec
        sbc.b BYTES_TO_WRITE_IN_BLOCK
        sta.b BYTES_TO_WRITE
        beql @end_writing_bytes
        jmp @do_write_directblock
@end_writing_bytes:
    rep #$30
    ldy #fs_memdev_inode_t.size
    lda [DEST],Y
    sec
    sbc.b INITIAL_SIZE
    pld
    rtl
.UNDEFINE SOURCE
.UNDEFINE DEST
.UNDEFINE BYTES_TO_WRITE
.UNDEFINE ROOT_PTR
.UNDEFINE DIRECT_PTR
.UNDEFINE DIRECT_INDEX
.UNDEFINE INITIAL_SIZE
.UNDEFINE BYTES_TO_WRITE_IN_BLOCK

; [x16]u16 alloc([s16]fs_device_instance_t *dev, [s24]fs_inode_info_t* data);
; data: $04,S
; dev: $07,S
_memfs_alloc:
    phb
; get header
    rep #$30
    lda 1+$07,S
    tax
    sep #$20
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
    pha
    plb
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
    xba
    lda #0
    tax ; X = first_bank:first_page:00
; get and swap inode
    ; setup pointer
    rep #$20
    stz.b $00
    lda.w fs_memdev_root_t.inode_next_free,X
    bne @has_next_inode
        ldx #0
        plb
        rtl
@has_next_inode:
    sta.b $00+1
    ; ROOT->next = ROOT->next->next
    ldy #fs_memdev_inode_t.inode_next
    lda [$00],Y
    sta.w fs_memdev_root_t.inode_next_free,X
    ; NODE->next = NULL
    lda #0
    sta [$00],Y
; set base inode data
    ; NODE->nlink = 0
    ldy #fs_memdev_inode_t.nlink
    sta [$00],Y
    ; NODE->size = 0
    ldy #fs_memdev_inode_t.size
    sta [$00],Y
    ldy #fs_memdev_inode_t.size+2
    sta [$00],Y
; copy data into inode
    ; setup pointer
    lda 1+$04,S
    sta.b $03
    lda 1+$04+1,S
    sta.b $03+1
    ; copy type
    ldy #fs_inode_info_t.type
    lda [$03],Y
    sta [$00],Y
; update root data
    lda.w fs_memdev_root_t.num_used_inodes,X
    inc A
    sta.w fs_memdev_root_t.num_used_inodes,X
    lda.w fs_memdev_root_t.num_free_inodes,X
    dec A
    sta.w fs_memdev_root_t.num_free_inodes,X
; pull bank
    plb
; clear directory, if type is DIR
    ldy #fs_memdev_inode_t.type
    lda [$00]
    cmp #FS_INODE_TYPE_DIR
    bne @inode_is_not_dir
        phb
        sep #$20
        lda.b $02
        pha
        plb
        ldx.b $00
        jsr _clear_dir
        plb
@inode_is_not_dir:
; end
    ldx.b $00+1
    rtl

; void link([s16]fs_device_instance_t *dev, [s24]char *name, [s16]u16 source, [s16]u16 dest)
; dest $04,S
; source $06,S
; name $08,S
; dev $0B,S
_memfs_link:
    rep #$30
    lda $04,S
    stz.b $00
    sta.b $00+1
    ; loop until free slot found
    ldy #fs_memdev_inode_t.dir.dirent
@loop_search_slot:
        lda [$00],Y
        beq @found_slot
        tya
        clc
        adc #16
        tay
        cmp #256
        bcc @loop_search_slot
        ; reached end of inode, fail
        lda #0
        rtl
@found_slot:
    ; sty.b $06
; copy source into slot
    lda $06,S
    sta [$00],Y
; copy name into slot
    lda $08,S
    sta.b $03
    lda $08+1,S
    sta.b $03+1
    .REPT (FSMEM_DIR_MAX_INODE_COUNT/2)
        iny
        iny
        lda [$03]
        sta [$00],Y
        inc.b $03
        inc.b $03
    .ENDR
    iny
    iny
; set next inode to 0 (if Y <256)
    cpy #256
    bcs +
        tya
        lda #0
        sta [$00],Y
    +:
; indicate to source that it has been linked to
    lda $06,S
    stz.b $00
    sta.b $00+1
    ldy #fs_memdev_inode_t.nlink
    lda [$00],Y
    inc A
    sta [$00],Y
; end
    lda #1
    rtl

; void unlink([s16]fs_device_instance_t *dev, [s16]u16 source, [u16]u16 dest);
; dest $04,S
; source $06,S
; dev $08,S
_memfs_unlink:
    rep #$30
    .DEFINE NODE_PTR kTmpPtrL
    .DEFINE PARENT_PTR kTmpPtrL2
    .DEFINE DIRECTBLOCK_PTR kTmpBuffer
    .DEFINE ROOT_PTR (kTmpBuffer+3)
    .DEFINE DIRECTBLOCK_INDEX (kTmpBuffer+6)
    .DEFINE DIRECTBLOCK_COUNT (kTmpBuffer+8)
    phd
    lda #$0000
    tcd
; setup pointers
    rep #$30
    stz.b NODE_PTR
    stz.b PARENT_PTR
    lda 2+$06,S
    sta.b NODE_PTR+1
    lda 2+$04,S
    sta.b PARENT_PTR+1
; check nodes are not null
    lda 2+$04,S
    bne +
    @fail:
        lda #0
        pld
        rtl
    +:
    lda 2+$06,S
    beq @fail
; check that (NODE is FILE) or (NODE is DIR and (NODE.dirent[0].blockId != 0 or NODE.nlink > 1))
    ldy #fs_memdev_inode_t.type
    lda [NODE_PTR],Y
    cmp #FS_INODE_TYPE_FILE ; NODE is FILE => success
    beq @node_is_good
    cmp #FS_INODE_TYPE_DIR ; not NODE is DIR => fail
    bne @fail
        ldy #fs_memdev_inode_t.nlink
        lda [NODE_PTR],Y
        cmp #2
        bcs @node_is_good ; NODE.nlink >= 2 => success
        ldy #fs_memdev_inode_t.dir.dirent.1.blockId
        lda [NODE_PTR],Y
        bne @fail ; NODE.dirent[0].blockId != 0 => fail
@node_is_good:
; decrement link count
    ldy #fs_memdev_inode_t.nlink
    lda [NODE_PTR],Y
    beq +
        dec A
    +:
    sta [NODE_PTR],Y
; remove from parent
    ; go to index of node
    ldy #fs_memdev_inode_t.dir.dirent.1
@loop_search_node:
        lda [PARENT_PTR],Y
        cmp.b NODE_PTR+1
        beq @found_in_node
        tya
        clc
        adc #16
        tay
        cmp #256
        bcs @search_failed ; search failed... somehow
        jmp @loop_search_node
@found_in_node:
    ; now, copy bytes until Y>= 240
@loop_copy_bytes:
        cpy #240
        bcs @remove_end
        tyx
        tya
        clc
        adc #16
        tay
        lda [PARENT_PTR],Y
        txy
        sta [PARENT_PTR],Y
        iny
        iny
        jmp @loop_copy_bytes
@remove_end:
@search_failed:
    ; copy one empty entry
    lda #0
    sta [PARENT_PTR],Y
    ; handle deletion, possibly
    ldy #fs_memdev_inode_t.nlink
    lda [NODE_PTR],Y
    bnel @dont_free_node
        lda 2+$08,S
        tax
        sep #$20
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
        sta.b ROOT_PTR+2
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
        sta.b ROOT_PTR+1
        stz.b ROOT_PTR ; [$03] is now ROOT
        rep #$30
        ; NODE->next = ROOT->next
        ldy #fs_memdev_root_t.inode_next_free
        lda [ROOT_PTR],Y
        ldy #fs_memdev_inode_t.inode_next
        sta [NODE_PTR],Y
        ; ROOT->next = NODE
        ldy #fs_memdev_root_t.inode_next_free
        lda.b NODE_PTR+1
        sta [ROOT_PTR],Y
        ; NODE->type = NONE
        ldy #fs_memdev_inode_t.type
        lda #FS_INODE_TYPE_EMPTY
        sta [NODE_PTR],Y
        ; ROOT->num_used_inodes--
        ldy #fs_memdev_root_t.num_used_inodes
        lda [ROOT_PTR],Y
        dec A
        sta [ROOT_PTR],Y
        ; ROOT->num_free_inodes++
        ldy #fs_memdev_root_t.num_free_inodes
        lda [ROOT_PTR],Y
        inc A
        sta [ROOT_PTR],Y
        ; free direct nodes, if necessary
        ldy #fs_memdev_inode_t.size
        lda [NODE_PTR],Y
        clc
        adc #256-192-1
        xba
        and #$00FF
        beq @end_free_directblock
        .AMAXU P_IMM 16
        sta.b DIRECTBLOCK_COUNT
        ldy #fs_memdev_inode_t.file.directBlocks
        sty.b DIRECTBLOCK_INDEX
    @loop_free_directblock:
            ; setup pointer
            ldy.b DIRECTBLOCK_INDEX
            lda [NODE_PTR],Y
            stz.b DIRECTBLOCK_PTR
            sta.b DIRECTBLOCK_PTR+1
            ; DIRECT->next = ROOT->next
            ; TODO: could probably speed up by linking each node together, then
            ; linking root to first node, but this is easier for now
            ldy #fs_memdev_root_t.inode_next_free
            lda [ROOT_PTR],Y
            ldy #fs_memdev_inode_t.inode_next
            sta [DIRECTBLOCK_PTR],Y
            ; ROOT->next = DIRECT
            ldy #fs_memdev_root_t.inode_next_free
            lda.b DIRECTBLOCK_PTR+1
            sta [ROOT_PTR],Y
            ; DIRECT->type = NONE
            ldy #fs_memdev_inode_t.type
            lda #FS_INODE_TYPE_EMPTY
            sta [DIRECTBLOCK_PTR],Y
            ; DIRECT->nlink = 0
            ldy #fs_memdev_inode_t.nlink
            lda #0
            sta [DIRECTBLOCK_PTR],Y
            ; ROOT->num_used_inodes--
            ldy #fs_memdev_root_t.num_used_inodes
            lda [ROOT_PTR],Y
            dec A
            sta [ROOT_PTR],Y
            ; ROOT->num_free_inodes++
            ldy #fs_memdev_root_t.num_free_inodes
            lda [ROOT_PTR],Y
            inc A
            sta [ROOT_PTR],Y
            ; iterate
            dec.b DIRECTBLOCK_COUNT
            beq @end_free_directblock
            inc.b DIRECTBLOCK_INDEX
            inc.b DIRECTBLOCK_INDEX
            jmp @loop_free_directblock
    @end_free_directblock:
@dont_free_node:
    lda #1
    pld
    rtl
.UNDEFINE NODE_PTR
.UNDEFINE PARENT_PTR
.UNDEFINE DIRECTBLOCK_PTR
.UNDEFINE ROOT_PTR
.UNDEFINE DIRECTBLOCK_INDEX
.UNDEFINE DIRECTBLOCK_COUNT

; void info([s16]fs_device_instance_t *dev, [s16]u16 inode_id, [s24]fs_inode_info_t *data)
; data     $04
; inode_id $07
; dev      $09
_memfs_info:
    rep #$30
; setup pointers
    lda $04,S
    sta.b $00
    lda $04+1,S
    sta.b $00+1 ; [$00] = data*
    stz.b $03
    lda $07,S
    sta.b $03+1 ; [$03] = inode*
; load data
    ldy #fs_memdev_inode_t.type
    lda [$03],Y
    ldy #fs_inode_info_t.type
    sta [$00],Y
    ldy #fs_memdev_inode_t.size
    lda [$03],Y
    ldy #fs_inode_info_t.size
    sta [$00],Y
    ldy #fs_memdev_inode_t.size+2
    lda [$03],Y
    ldy #fs_inode_info_t.size+2
    sta [$00],Y
; end
    rtl

.DSTRUCT KFS_DeviceType_Mem INSTANCEOF fs_device_template_t VALUES
    fsname .db "MEM\0"
    init   .dw _memfs_init
    lookup .dw _memfs_lookup
    read   .dw _memfs_read
    write  .dw _memfs_write
    alloc  .dw _memfs_alloc
    link   .dw _memfs_link
    unlink .dw _memfs_unlink
    info   .dw _memfs_info
.ENDST

.ENDS
