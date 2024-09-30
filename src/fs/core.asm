.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KFSCore" FREE

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

; find a device for the given path piece in X
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
    rts

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
    ; Find file device
    ; end
@end:
    sep #$20
    .RestoreInt__ ; -1 (0)
    rtl
.UNDEFINE P_FNAME
.UNDEFINE P_MODE

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
; TODO: proper dynamic mounting
    ldx #loword(kfsDeviceInstanceTable)
    lda #loword(kfsDeviceTemplateTable)
    sta.l $7E0000 + fs_device_instance_t.template,X
    sep #$20
    lda #'t'
    sta.l $7E0000 + fs_device_instance_t.mount_name+0,X
    lda #'m'
    sta.l $7E0000 + fs_device_instance_t.mount_name+1,X
    lda #'p'
    sta.l $7E0000 + fs_device_instance_t.mount_name+2,X
    lda #'\0'
    sta.l $7E0000 + fs_device_instance_t.mount_name+3,X
; end
    rtl

.ENDS