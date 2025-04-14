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
    num_banks        .db $80
    num_blocks_total .dw $4000
; inode layout
    num_used_inodes  .dw $0005
    num_total_inodes .dw $4000
    num_free_inodes  .dw ($4000 - 5)
    inode_next_free  .dw $0000
; directory
    dirent.1.blockId .dw $0081
    dirent.1.name .db "bar\0"
    dirent.2.blockId .dw $0082
    dirent.2.name .db "foo\0"
    dirent.3.blockId .dw $0083
    dirent.3.name .db "hello\0"
    dirent.4.blockId .dw $0000
.ENDST

; $0081 FILE: 'bar'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 5, 0
    inode_next .dw $0000
    file.directData .db "BAR!\0"
.ENDST

; $0082 FILE: 'foo'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 5, 0
    inode_next .dw $0000
    file.directData .db "FOO!\0"
.ENDST

; $0083 DIR: 'hello'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_DIR
    nlink .dw 1
    inode_next .dw $0000
; directory
    dir.dirent.1.blockId .dw $0084
    dir.dirent.1.name .db "world\0"
    dir.dirent.2.blockId .dw $0000
.ENDST

; $0084 FILE: 'world'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 14, 0
    inode_next .dw $0000
    file.directData .db "Hello, World!\0"
.ENDST

.ENDS