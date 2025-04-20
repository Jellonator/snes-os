.include "base.inc"

; Call given virtual function on device
; X must be a pointer to a fs_device_template_t
.MACRO .FsCall ARGS func
    ; setup return address
    phk
    pea @@@@@\.\@ - 1
    ; setup target address
    sep #$20
    lda.l $7E0002,X
    pha
    sta.b $02
    rep #$20
    lda.l $7E0000,X
    clc
    adc #func
    sta.b $00
    lda [$00]
    dec A
    pha
    ; call
    rtl
@@@@@\.\@:
.ENDM

.BANK $01 SLOT "ROM"
.SECTION "KFSCore" FREE

; Static filesystem (unchanging)
kfsDeviceStaticPath:
    .db "static\0"

.DSTRUCT kfsDeviceStaticData INSTANCEOF fs_device_instance_mem_data_t VALUES
    bank_first      .db $80
    bank_last       .db $FF
    page_first      .db $80
    page_last       .db $FF
    blocks_per_bank .db $80
    num_banks       .db $80
    blocks_total    .dw $4000
    mode            .dw FS_DEVICE_MODE_READABLE
.ENDST

; Volatile filesystem (resets on startup)
kfsDeviceTempPath:
    .db "tmp\0"

.DSTRUCT kfsDeviceTempData INSTANCEOF fs_device_instance_mem_data_t VALUES
    bank_first      .db $7E
    bank_last       .db $7E
    page_first      .db $C0
    page_last       .db $FF
    blocks_per_bank .db $40
    num_banks       .db $01
    blocks_total    .dw $0040
    mode            .dw FS_DEVICE_MODE_READABLE | FS_DEVICE_MODE_WRITABLE
.ENDST

; Home filesystem (saved between sessions)
kfsDeviceHomePath:
    .db "home\0"

.DSTRUCT kfsDeviceHomeData INSTANCEOF fs_device_instance_mem_data_t VALUES
    bank_first      .db $70
    bank_last       .db $73
    page_first      .db $00
    page_last       .db $7F
    blocks_per_bank .db $80
    num_banks       .db $04
    blocks_total    .dw $0200
    mode            .dw FS_DEVICE_MODE_READABLE | FS_DEVICE_MODE_WRITABLE
.ENDST

; find an open file handle and store a pointer to it in X
_fs_get_open_file_handle:
    ; Find empty file descriptor
    rep #$30
    ldx #loword(kfsFileHandleTable)
    @find_fh_loop:
        lda.l $7E0000 + fs_handle_instance_t.state,X
        and #FS_TABLE_FLAG_OPEN
        beq @find_fh_end ; file descriptor is closed, use it
        txa
        clc
        adc #_sizeof_fs_handle_instance_t
        cmp #kfsFileHandleTable + (_sizeof_fs_handle_instance_t*FS_OFT_SIZE)
        bcc +
            ; fail; no more descriptors available
            ldx #0
            rts
        +:
        tax
        jmp @find_fh_loop
    @find_fh_end:
    rts

; Find a device for the given path piece in X
; Returns found device in Y
kfsFindDevicePointer:
    rep #$30
    ;
    phb ; [+1, 1] $03,S = original bank
    phx ; [+2, 3] $01,S = original path
    .ChangeDataBank $7E
    ;
    ldy #loword(kfsDeviceInstanceTable)
@loop:
    lda.w fs_device_instance_t.template,Y
    beq @null_device
        ; non-null instance, check path
        phy ; [+2, 5]
        ; push path piece. We must do this each time since path_compare_pieces
        ; modifies the path on the stack.
        sep #$20
        lda 2+$03,S
        pha ; [+1; 6]
        rep #$30
        lda 3+$01,S
        pha ; [+2; 8]
        ; push device name to compare to
        phb ; [+1; 9]
        tya
        clc
        adc #fs_device_instance_t.mount_name
        pha ; [+2; 11]
        ; compare pieces
        jsl pathPieceCmp
        .ACCU 8
        .INDEX 16
        cmp #0
        bne @path_neq
            ; found path, return with path
            rep #$30
            .POPN 6 ; [-6; 5]
            ply ; [-2; 3]
            plx ; [-2; 1]
            plb ; [-1; 0]
            rtl
        @path_neq:
        ; path not found, clean up for next instance
        rep #$30
        .POPN 6 ; [-6; 5]
        ply ; [-2; 3]
    @null_device:
    ; increment device instance
    .ACCU 16
    .INDEX 16
    tya
    clc
    adc #_sizeof_fs_device_instance_t
    tay
    ; check instance pointer is in bounds
    cmp #loword(kfsDeviceInstanceTable)+(FS_DEVICE_INSTANCE_MAX_COUNT*_sizeof_fs_device_instance_t)
    bcc @loop
; none found
    plx ; [-2; 1]
    plb ; [-1; 0]
    ldy #0
    rtl

; Open a file
; [X]fs_device_instance_t *fs_open([X]char *filename)
fsOpen:
    ; TODO: add 'mode'
    ; TODO: fail for read-only nodes and filesystems, if mode is 'write'
    phx ; [+2, 2]
    ; check string length <= FS_MAX_FILENAME_LEN
    sep #$30
    .DisableInt__ ; [+1, 3]
    ; Find empty file descriptor
    jsr _fs_get_open_file_handle
    rep #$30
    cpx #0
    bne +
        jmp @end_null
    +:
    phx ; [+2, 5]
    ; Find file device
    lda $04,S ; load path
    tax
    lda.w $0000,X
    and #$00FF
    cmp #'/'
    bne +
        inx
    +:
    jsl kfsFindDevicePointer
    rep #$30
    cpy #0
    bne +
        .POPN 2
        jmp @end_null
    +:
    phy ; [+2, 7]
    ; Call into device to get inode
    lda $06,S ; load path
    tax
    jsl pathGetTailPtr
    rep #$30
    phb ; [+1, 8]
    phx ; [+2, 10]
    lda $04,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.lookup
    .POPN 3 ; [-3, 7]
    rep #$30
    ; check inode
    cpx #0
    bne +
        .POPN 4
        jmp @end_null
    +:
    phx ; [+2, 9]
    ; success! now write out
    rep #$30
    lda $05,S
    tax
    lda #FS_TABLE_FLAG_OPEN
    sta.l $7E0000 + fs_handle_instance_t.state,X
    lda #0
    sta.l $7E0000 + fs_handle_instance_t.fileptr,X
    ; TODO: change fileptr depending on mode (set to size if mode is append)
    lda $03,S
    sta.l $7E0000 + fs_handle_instance_t.device,X
    lda $01,S
    sta.l $7E0000 + fs_handle_instance_t.inode,X
    .POPN 6
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$10
    ldy #0
    rtl
@end_null:
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$10
    ldx #0
    ldy #0
    rtl

; Close an open file handle
; void fsClose([X]fs_handle_instance_t *handle)
fsClose:
    .INDEX 16
    sep #$20
    lda #0
    sta.l $7E0000 + fs_handle_instance_t.state,X
    ; TODO: call into device?
    rtl

; Seek to position in file handle
; void fsSeek([X]fs_handle_instance_t *handle)
fsSeek:
    .INDEX 16
    .ACCU 16
    sta.l $7E0000 + fs_handle_instance_t.fileptr,X
    ; TODO: call into device?
    ; TODO: maybe make a syscall for this, since seek is probably broken for
    ; directories (since fileptr is a bit odd).
    rtl

; Read bytes from file in file handle
; [a16]u16 fsRead([x16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; buffer: $06,S
; nbytes: $04,S
fsRead:
    ; TODO: check handle state for read-access
    .INDEX 16
    phx ; [+2, 2] PARAM fh
    sep #$20
    lda 2+$08,S
    pha ; [+1, 3] PARAM buffer (bank)
    rep #$30
    lda 3+$06,S
    pha ; [+2, 5] PARAM buffer
    lda 5+$04,S
    pha ; [+2; 7] PARAM nbytes
    lda.l $7E0000 + fs_handle_instance_t.device,X
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X
    tax
    .FsCall fs_device_template_t.read
    sta.b $00
    .POPN 5
    rep #$30
    plx
    lda.b $00
    rtl

; Write bytes to file in file handle
; [a16]u16 fsWrite([x16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; buffer: $06,S
; nbytes: $04,S
fsWrite:
    ; TODO: check handle state for write-access
    rep #$30
    phx ; [+2, 2] PARAM fh
    sep #$20
    lda 2+$08,S
    pha ; [+1, 3] PARAM buffer (bank)
    rep #$30
    lda 3+$06,S
    pha ; [+2, 5] PARAM buffer
    rep #$30
    lda 5+$04,S
    pha ; [+2, 7] PARAM nbytes
    lda.l $7E0000 + fs_handle_instance_t.device,X
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X
    tax
    .FsCall fs_device_template_t.write
    sta.b $00
    .POPN 5 ; [-5, 2]
    rep #$30
    plx ; [-2, 0]
    lda.b $00
    rtl

; Remove file
; [a16] bool fsRemove([x16]char *path)
fsRemove:
    .INDEX 16
; search for inode
    phx ; [+2, 2]
    .DEFINE S_FILENAME 2
    sep #$30
    .DisableInt__ ; [+1, 3]
    ; Find file device
    rep #$30
    lda 3-S_FILENAME+1,S ; load path
    tax
    lda.w $0000,X
    and #$00FF
    cmp #'/'
    bne +
        inx
    +:
    jsl kfsFindDevicePointer
    rep #$30
    cpy #0
    bne +
        jmp @end_null
    +:
    phy ; [+2, 5]
    .DEFINE S_DEVICE_INSTANCE 5
    ; Call into device to get inode
    lda 5-S_FILENAME+1,S ; load path
    tax
    jsl pathGetTailPtr
    rep #$30
    phb ; [+1, 6]
    phx ; [+2, 8]
    .DEFINE S_SUBPATH 8
    lda 8-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.lookup
    rep #$30
    .POPN 3 ; [-3, 5]
    ; check inode is not null
    rep #$30
    cpx #0
    bne +
        .POPN 2
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
    phx ; [+2, 7]
    .DEFINE S_SOURCE 10
    phy ; [+2; 9]
    .DEFINE S_DEST 12
    ; check that no files in OFT reference inode
    ldx.w #loword(kfsFileHandleTable)
    @search_table_loop:
        lda.l fs_handle_instance_t.state,X
        and #FS_TABLE_FLAG_OPEN
        beq @search_table_skip ; skip this file, it is not open
        lda 9-S_DEVICE_INSTANCE,S
        cmp.l fs_handle_instance_t.device,X
        bne @search_table_skip
        lda.b 9-S_DEST,S
        cmp.l fs_handle_instance_t.inode,X
        bne @search_table_skip
            ; open file matches device and inode, so we can not unlink. fail.
            .POPN 6
            jmp @end_null
            .ACCU 16
            .INDEX 16
    @search_table_skip:
        txa
        clc
        adc #_sizeof_fs_handle_instance_t
        cmp #kfsFileHandleTable + (_sizeof_fs_handle_instance_t*FS_OFT_SIZE)
        bcs @search_table_end
        tax
        jmp @search_table_loop
    @search_table_end:
    ; unlink file.
    ; This may fail if the node is a folder with a file in it.
    lda 9-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.unlink
    rep #$30
    sta.b $00
    .POPN 6
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$30
    lda.b $00
    rtl
@end_null:
    ; ASSUME stack is +3
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$30
    lda #0
    rtl
.UNDEFINE S_FILENAME
.UNDEFINE S_DEVICE_INSTANCE
.UNDEFINE S_SUBPATH
.UNDEFINE S_SOURCE
.UNDEFINE S_DEST

.DSTRUCT _fs_base_file INSTANCEOF fs_inode_info_t VALUES
    type .dw FS_INODE_TYPE_FILE
.ENDST

.DSTRUCT _fs_base_dir INSTANCEOF fs_inode_info_t VALUES
    type .dw FS_INODE_TYPE_DIR
.ENDST

; Create a directory. Return `1` if successful.
; [a16]u16 fsMakeDir([x16]char *filename);
fsMakeDir:
    .INDEX 16
    phx ; [+2, 2] - char *filename
    .DEFINE S_FILENAME 2
    ; check string length <= FS_MAX_FILENAME_LEN
    sep #$30
    .DisableInt__ ; [+1, 3] - interrupt
    .DEFINE S_INT 3
; Find file device
    rep #$30
    lda 3-S_FILENAME+1,S ; load path
    tax
    lda.w $0000,X
    and #$00FF
    cmp #'/'
    bne +
        inx
    +:
    jsl kfsFindDevicePointer
    rep #$30
    cpy #0
    bne +
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
    phy ; [+2, 5] - fs_device_instance_t*
    .DEFINE S_DEVICE_INSTANCE 5
; Search for parent inode
    lda 5-S_FILENAME+1,S ; load path
    tax
    jsl pathGetTailPtr
    rep #$30
    phb ; [+1, 6] - char* path_sub
    phx ; [+2, 8]
    .DEFINE S_SUBPATH 8
    lda 8-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.lookup
    rep #$30
    ; check inode (NODE must be NULL, PARENT must be VALID)
    cpx #0
    beq +
        .POPN 5
        jmp @end_null
        rtl
        .ACCU 16
        .INDEX 16
    +:
    cpy #0
    bne +
        .POPN 5
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
    ; set up stack for later link
    phx ; [+2; 10]
    .DEFINE S_SOURCE 10
    phy ; [+2; 12]
    .DEFINE S_DEST 12
    ; check path (must be basename; not empty, no separators)
    lda 12-S_SUBPATH+1,S
    tax
    lda.w $0000,X
    cmp #'/'
    bne +
        inx
        txa
        sta $01,S
    +:
    jsl pathIsName
    .ACCU 8
    cmp #0
    bne +
        .POPN 9
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
; Allocate new inode
    rep #$30
    lda 12-S_DEVICE_INSTANCE+1,S
    pha ; [+2; 14]
    .PEAL _fs_base_dir ; [+3; 17]
    rep #$20
    lda 17-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.alloc
    rep #$30
    txa
    sta 17-S_SOURCE+1,S
    .POPN 5 ; [-5; 12]
    ; check new node is not null (allocation error)
    rep #$30
    lda 12-S_SOURCE+1,S
    cmp #0
    bne +
        .POPN 9
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
; link new inode
    rep #$20
    lda 12-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.link
    ; just assume the link succeeded tbh
    ; TODO: handle link error
; success! now return true
    rep #$30
    .POPN 9 ; [-9, 3]
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$30
    lda #1
    rtl
@end_null:
    ; ASSUME stack is +3
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$30
    lda #0
    rtl
.UNDEFINE S_FILENAME
.UNDEFINE S_INT
.UNDEFINE S_DEVICE_INSTANCE
.UNDEFINE S_SUBPATH
.UNDEFINE S_SOURCE
.UNDEFINE S_DEST

; Create a file, and return its file handle
; [x16]u16 fsCreate([x16]char *filename);
fsCreate:
    ; TODO: fail if device is read-only
    .INDEX 16
    phx ; [+2, 2] - char *filename
    .DEFINE S_FILENAME 2
    ; check string length <= FS_MAX_FILENAME_LEN
    sep #$30
    .DisableInt__ ; [+1, 3] - interrupt
    .DEFINE S_INT 3
; Find empty file descriptor
    jsr _fs_get_open_file_handle
    rep #$30
    cpx #0
    bne +
        jmp @end_null
    +:
    phx ; [+2, 5] - fs_handle_instance_t*
    .DEFINE S_FILE_HANDLE 5
; Find file device
    lda 5-S_FILENAME+1,S ; load path
    tax
    lda.w $0000,X
    and #$00FF
    cmp #'/'
    bne +
        inx
    +:
    jsl kfsFindDevicePointer
    rep #$30
    cpy #0
    bne +
        .POPN 2
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
    phy ; [+2, 7] - fs_device_instance_t*
    .DEFINE S_DEVICE_INSTANCE 7
; Search for parent inode
    lda 7-S_FILENAME+1,S ; load path
    tax
    jsl pathGetTailPtr
    rep #$30
    phb ; [+1, 8] - char* path_sub
    phx ; [+2, 10]
    .DEFINE S_SUBPATH 10
    lda 10-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.lookup
    rep #$30
    ; check inode (NODE must be NULL, PARENT must be VALID)
    cpx #0
    beq +
        ; node was found, return node.
        stx.b $00
        .POPN 7
        sep #$20
        .RestoreInt__ ; [-1, 2]
        .POPN 2 ; [-2, 0]
        rep #$10
        ldx.b $00
        ldy #0
        ; TODO: check node type (must be a file)
        rtl
        .ACCU 16
        .INDEX 16
    +:
    cpy #0
    bne +
        .POPN 7
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
    ; set up stack for later link
    phx ; [+2; 12]
    .DEFINE S_SOURCE 12
    phy ; [+2; 14]
    .DEFINE S_DEST 14
    ; check path (must be basename; not empty, no separators)
    lda 14-S_SUBPATH+1,S
    tax
    lda.w $0000,X
    cmp #'/'
    bne +
        inx
        txa
        sta $01,S
    +:
    jsl pathIsName
    .ACCU 8
    cmp #0
    bne +
        .POPN 11
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
; Allocate new inode
    rep #$30
    lda 14-S_DEVICE_INSTANCE+1,S
    pha ; [+2; 16]
    .PEAL _fs_base_file ; [+3; 19]
    rep #$20
    lda 19-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.alloc
    rep #$30
    txa
    sta 19-S_SOURCE+1,S
    .POPN 5 ; [-5; 14]
    ; check new node is not null (allocation error)
    rep #$30
    lda 14-S_SOURCE+1,S
    cmp #0
    bne +
        .POPN 11
        jmp @end_null
        .ACCU 16
        .INDEX 16
    +:
; link new inode
    rep #$20
    lda 14-S_DEVICE_INSTANCE+1,S ; load device
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X ; load template
    tax
    .FsCall fs_device_template_t.link
    ; just assume the link succeeded tbh
    ; TODO: handle link error
; success! now write out
    rep #$30
    lda 14-S_FILE_HANDLE+1,S
    tax
    lda #FS_TABLE_FLAG_OPEN
    sta.l $7E0000 + fs_handle_instance_t.state,X
    lda #0
    sta.l $7E0000 + fs_handle_instance_t.fileptr,X
    lda 14-S_DEVICE_INSTANCE+1,S
    sta.l $7E0000 + fs_handle_instance_t.device,X
    lda 14-S_SOURCE+1,S
    sta.l $7E0000 + fs_handle_instance_t.inode,X
    .POPN 11
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$10
    ldy #0
    rtl
@end_null:
    ; ASSUME stack is +3
    sep #$20
    .RestoreInt__ ; [-1, 2]
    .POPN 2 ; [-2, 0]
    rep #$10
    ldx #0
    ldy #0
    rtl
.UNDEFINE S_FILENAME
.UNDEFINE S_INT
.UNDEFINE S_FILE_HANDLE
.UNDEFINE S_DEVICE_INSTANCE
.UNDEFINE S_SUBPATH
.UNDEFINE S_SOURCE
.UNDEFINE S_DEST

; mount device, returns pointer to device in X
; Push order:
; device [dw], $0A
; data   [dl], $07
; name   [dl], $04
kfsMount:
    ; find free device
    rep #$30
    ldx #loword(kfsDeviceInstanceTable)
@loop:
    lda.l $7E0000 + fs_device_instance_t.template,X
    beq @found
    ; increment device instance
    txa
    clc
    adc #_sizeof_fs_device_instance_t
    tax
    ; check instance pointer is in bounds
    cmp #loword(kfsDeviceInstanceTable)+(FS_DEVICE_INSTANCE_MAX_COUNT*_sizeof_fs_device_instance_t)
    bcc @loop
; none found
    ldx #0
    rtl
@found:
    lda $0A,S
    sta.l $7E0000 + fs_device_instance_t.template,X
    phx
    ; copy name
    tsc
    phd
    tcd
    sep #$20
    ldy #0
@loop_write:
    lda.b [2+$04],Y
    sta.l $7E0000 + fs_device_instance_t.mount_name,X
    inx
    iny
    cpy #FS_MAX_FILENAME_LEN
    bcs @end_write
    cmp #0
    bne @loop_write
@end_write
    ; copy data
    rep #$30
    lda 2+$01,S
    tax
    ; rep #$20
    ldy #0
@loop_data:
    lda.b [2+$07],Y
    sta.l $7E0000 + fs_device_instance_t.data,X
    inx
    inx
    iny
    iny
    cpy #16
    bcc @loop_data
    pld
    ; init
    rep #$30
    lda $01,S
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X
    tax
    .FsCall fs_device_template_t.init
    ; end
    rep #$30
    plx
    rtl

kfsInit__:
    rep #$30
; clear device templates
    ldx #0
    ldy #FS_DEVICE_TYPE_MAX_COUNT
    lda #0
    -:
        sta.l kfsDeviceTemplateTable,X
        sta.l kfsDeviceTemplateTable+1,X
        inx
        inx
        inx
        dey
    bne -
; clear device instances
    ldx #loword(kfsDeviceInstanceTable)
    ldy #FS_DEVICE_INSTANCE_MAX_COUNT
    -:
        lda #0
        sta.l $7E0000 + fs_device_instance_t.template,X
        txa
        clc
        adc #_sizeof_fs_device_instance_t
        tax
        dey
    bne -
; clear open file table
    ldx #kfsFileHandleTable
    ldy #FS_OFT_SIZE
    -:
        lda #0
        sta.l $7E0000 + fs_handle_instance_t.state,X
        txa
        clc
        adc #_sizeof_fs_handle_instance_t
        tax
        dey
    bne -
; register devices
    sep #$30
    lda #bankbyte(KFS_DeviceType_Mem)
    sta.l kfsDeviceTemplateTable+2
    rep #$30
    lda #loword(KFS_DeviceType_Mem)
    sta.l kfsDeviceTemplateTable
; mount devices
; For now, just hard-code some mounted devices.
    pea kfsDeviceTemplateTable
    .PEAL kfsDeviceTempData
    .PEAL kfsDeviceTempPath
    jsl kfsMount
    .POPN 6
    .PEAL kfsDeviceStaticData
    .PEAL kfsDeviceStaticPath
    jsl kfsMount
    .POPN 6
    .PEAL kfsDeviceHomeData
    .PEAL kfsDeviceHomePath
    jsl kfsMount
    .POPN 8
; end
    rtl

.ENDS