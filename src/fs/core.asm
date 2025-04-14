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
.ENDST

; find an open file handle and store a pointer to it in X
_fs_get_open_file_handle:
    ; Find empty file descriptor
    rep #$30
    ldx.w #loword(kfsFileHandleTable)
    @find_fh_loop:
        lda.w fs_handle_instance_t.state,X
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
; [X]fs_device_instance_t *fs_open([X]char *filename, [S]byte mode)
.DEFINE P_FNAME $05
.DEFINE P_MODE $04
fsOpen:
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
    rep #$30
    .POPN 3 ; [-3, 7]
    ; check inode
    cpx #0
    bne +
        .POPN 7
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
.UNDEFINE P_FNAME
.UNDEFINE P_MODE

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
    rtl

; Read bytes from file in file handle
; [a16]u16 fsRead([x16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; buffer: $06,S
; nbytes: $04,S
fsRead:
    .INDEX 16
    phx ; [+2, 2] PARAM fh
    sep #$20
    lda $08,S
    pha ; [+1, 3] PARAM buffer (bank)
    rep #$30
    lda $06,S
    pha ; [+2, 5] PARAM buffer
    lda.l $7E0000 + fs_handle_instance_t.device,X
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X
    .FsCall fs_device_template_t.read
    sta.b $00
    .POPN 3
    rep #$30
    plx
    lda.b $00
    rtl

; Write bytes to file in file handle
; [a16]u16 fsWrite([x16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
; buffer: $06,S
; nbytes: $04,S
fsWrite:
    .INDEX 16
    phx ; [+2, 2] PARAM fh
    sep #$20
    lda $08,S
    pha ; [+1, 3] PARAM buffer (bank)
    rep #$30
    lda $06,S
    pha ; [+2, 5] PARAM buffer
    lda.l $7E0000 + fs_handle_instance_t.device,X
    tax
    lda.l $7E0000 + fs_device_instance_t.template,X
    tax
    .FsCall fs_device_template_t.write
    sta.b $00
    .POPN 3
    rep #$30
    plx
    lda.b $00
    rtl

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