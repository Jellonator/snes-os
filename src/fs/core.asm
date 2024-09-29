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

_fs_find_device:
    rts

; Open a file
; [X]fs_device_instance_t *fs_open([S]long char *filename, [S]byte mode)
.DEFINE P_FNAME $05
.DEFINE P_MODE $04
fs_open:
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
    ldx #0
    ldy #FS_DEVICE_INSTANCE_MAX_COUNT
    lda #0
    -:
        sta.l kfsDeviceInstanceTable,X
        inx
        inx
        dey
    bne -
; clear open file table
    ldx #kfsFileHandleTable
    ldy #FS_OFT_SIZE
    -:
        lda #0
        sta.l fs_handle_instance_t.state,X
        txa
        clc
        adc #_sizeof_fs_handle_instance_t
        tax
        dey
    bne -
; end
    rtl

.ENDS