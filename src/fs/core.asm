.include "base.inc"


.MACRO .FsCall ARGS func
    ; setup return address
    phk
    pea @@@@@\.\@ - 1
    ; setup target address
    sep #$20
    lda.l $FE0002,X
    pha
    rep #$20
    lda.l $FE0000,X
    clc
    adc #func
    pha
    ; call
    rtl
@@@@@\.\@:
.ENDM

.BANK $01 SLOT "ROM"
.SECTION "KFSCore" FREE

; Static filesystem (unchanging)
kfsDeviceStatic:
    .db "static\0"

; Volatile filesystem (resets on startup)
kfsDeviceTemp:
    .db "tmp\0"

; Home filesystem (saved between sessions)
kfsDeviceHome:
    .db "home\0"

; find an open file handle and store a pointer to it in X
_fs_get_open_file_handle:
    ; Find empty file descriptor
    rep #$30
    ldx.w loword(kfsFileHandleTable)
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
        tax
        cpx #'/'
        bne + ; skip initial '/'
            inx
        +:
        phx ; [+2; 8]
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
; [X]fs_device_instance_t *fs_open([S]long char *filename, [S]byte mode)
.DEFINE P_FNAME $05
.DEFINE P_MODE $04
fsOpen:
    ; check string length <= FS_MAX_FILENAME_LEN
    sep #$30
    .DisableInt__ ; [+1; 1]
    ; phb ; [+1; 1]
    ; lda 2+P_FNAME+2,S
    ; pha ; tab
    ; plb
    ; rep #$30
    ; lda 2+P_FNAME,S
    ; tax
    ; jsl stringLen
    ; plb ; [-1; 1]
    ; cmp #FS_MAX_FILENAME_LEN
    ; bcc +
    ;     ; fail; name too long
    ;     ldx #0
    ;     jmp @end
    ; +:
    ; Find empty file descriptor
    jsr _fs_get_open_file_handle
    rep #$30
    cpx #0
    beq @end_null
    phx
    ; Find file device
    jsl kfsFindDevicePointer
    rep #$30
    cpy #0
    beq @end_null
    phy
    ; Call into device to get inode
    tyx
    phk
    pea @destination - 1
    sep #$20
    lda.l $FE0002,X
    pha
    rep #$20
    lda.l $FE0000,X
    clc
    adc #fs_device_template_t.lookup
    pha
    rtl
@destination:

    ; phd
    ; tyx
    ; end
@end_null:
    sep #$20
    .RestoreInt__ ; -1 (0)
    rep #$10
    ldx #0
    ldy #0
    rtl
.UNDEFINE P_FNAME
.UNDEFINE P_MODE

; mount device, returns pointer to device in X
; Push order:
; device [dw], $07
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
    lda $07,S
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
    ; end
@end_write
    pld
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
    pea kfsDeviceTemplateTable
    .PEAL kfsDeviceTemp
    jsl kfsMount
    .POPN 3
    .PEAL kfsDeviceStatic
    jsl kfsMount
    .POPN 3
    .PEAL kfsDeviceHome
    jsl kfsMount
    .POPN 5
; end
    rtl

.ENDS