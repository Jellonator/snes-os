.include "base.inc"

.SECTION "FS_Header" BANK $00 SLOT "ROM" ORGA $8000 FORCE

.DSTRUCT INSTANCEOF fs_memdev_root_t VALUES
    magicnum .db "MEM\0"
; layout info
    bank_first      .db $80
    bank_last       .db $FF
    page_first      .db $80
    page_last       .db $FF
    num_blocks_per_bank .db $80
    num_banks       .db $80
    num_blocks_total    .dw $4000
; inode layout
    num_used_inodes  .dw $0001
    num_total_inodes .dw $4000
    num_free_inodes  .dw $3FFF
    inode_next_free  .dw $0000
; directory
    dirent.1.blockId .dw $0081
    dirent.1.name .db "foo\0"
.ENDST

; FILE: 'foo'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 14, 0
    inode_next .dw $0000
    file.directData .db "Hello, World!\0"
.ENDST

.ENDS