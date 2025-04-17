.include "base.inc"

; Definitions for in-memory (RAM) filesystem device

.BANK $01 SLOT "ROM"
.SECTION "KFSMem" FREE

; Clear directory stored in X
_clear_dir:
    rep #$20
    lda #0
    .REPT 14 INDEX i
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
        inc.b BYTES_READ
        dec.b BYTES_TO_READ
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

; Write data from buffer into file
; [a16]u16 write([s16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; nbytes $04,S
; buffer $06,S
; fh     $09,S
_memfs_write:
    .DEFINE SOURCE $00
    .DEFINE DEST $03
    .DEFINE BYTES_TO_WRITE $06
    rep #$30
; check nbytes > 0
    lda $04,S
    bne @has_bytes
        lda #0
        rtl
@has_bytes:
; get dest ptr
    lda $09,S
    tax
    sep #$20
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
    sta.b DEST+2
    lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
    sta.b DEST+1
    stz.b DEST
; get source ptr
    lda $06,S
    sta.b SOURCE
    lda $07,S
    sta.b SOURCE+1
; determine number of bytes to write. For now, we just use `192` as the maximum file size
; TODO: implement indirect
    lda #192
    ldy #fs_memdev_inode_t.size
    sec
    sbc [DEST],Y
    .AMINU P_STACK $04
    sta.b BYTES_TO_WRITE
    cmp #0
    beq @end_write_loop
; write bytes
    ldy #fs_memdev_inode_t.file.directData
    @loop_write_bytes:
        lda [SOURCE]
        sta [DEST],Y
        inc.b SOURCE
        iny
        dec.b BYTES_TO_WRITE
        beq @end_write_loop
        jmp @loop_write_bytes
@end_write_loop:
; set new size
    ldy #fs_memdev_inode_t.size
    lda [DEST]
    clc
    adc.b BYTES_TO_WRITE
    sta [DEST]
; end
    rep #$30
    lda.b BYTES_TO_WRITE
    rtl

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
    .REPT (14/2)
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

; void unlink([s16]fs_device_instance_t *dev, [s24]char* path);
; path $04,S
; dev $07,S
_memfs_unlink:
    rep #$30
; first, get inode
    lda $07,S
    pha
    lda $05,S
    pha
    sep #$30
    lda $04,S
    pha
    jsl _memfs_lookup
; setup pointers
    rep #$30
    stz.b $00 ; [$00] = FOUND NODE
    stz.b $03 ; [$03] = PARENT NODE
    stx.b $01
    sty.b $04
    pla
    pla
    sep #$20
    pla
    rep #$30
; check nodes are not null
    cpx #0
    bne +
    @fail:
        lda #0
        rtl
    +:
    cpy #0
    beq @fail
; check that (NODE is FILE) or (NODE is DIR and (NODE.dirent[0].blockId != 0 or NODE.nlink > 1))
    ldy #fs_memdev_inode_t.type
    lda [$00],Y
    cmp #FS_INODE_TYPE_FILE ; NODE is FILE => success
    beq @node_is_good
    cmp #FS_INODE_TYPE_DIR ; not NODE is DIR => fail
    bne @fail
        ldy #fs_memdev_inode_t.nlink
        lda [$00],Y
        cmp #2
        bcs @node_is_good ; NODE.nlink >= 2 => success
        ldy #fs_memdev_inode_t.dir.dirent.1.blockId
        lda [$00],Y
        bne @fail ; NODE.dirent[0].blockId != 0 => fail
@node_is_good:
; decrement link count
    ldy #fs_memdev_inode_t.nlink
    lda [$00],Y
    beq +
        dec A
    +:
    sta [$00],Y
; remove from parent
    ; go to index of node
    ldy #fs_memdev_inode_t.dir.dirent.1
@loop_search_node:
        lda [$03],Y
        cmp.b $01
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
        lda [$03],Y
        txy
        sta [$03],Y
        iny
        iny
        jmp @loop_copy_bytes
@remove_end:
@search_failed:
    ; handle deletion, possibly
    ldy #fs_memdev_inode_t.nlink
    lda [$00],Y
    bne @dont_free_node
        lda $07,S
        tax
        sep #$20
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.bank_first,X
        sta.b $03+2
        lda.l $7E0000 + fs_device_instance_t.data + fs_device_instance_mem_data_t.page_first,X
        sta.b $03+1
        stz.b $03 ; [$03] is now ROOT
        rep #$30
        ; NODE->next = ROOT->next
        ldy #fs_memdev_root_t.inode_next_free
        lda [$03],Y
        ldy #fs_memdev_inode_t.inode_next
        sta [$00],Y
        ; ROOT->next = NODE
        ldy #fs_memdev_root_t.inode_next_free
        lda.b $01
        sta [$03],Y
@dont_free_node:
    lda #1
    rtl

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
    info   .dw _memfs_info
.ENDST

.ENDS
