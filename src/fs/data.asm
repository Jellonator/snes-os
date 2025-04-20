.include "base.inc"

.SECTION "FS_Header" BANK $00 SLOT "ROM" ORGA $8000 FORCE

.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_ROOT
    nlink .dw 0
    size .dw 5, 0
    inode_next .dw $0000
    root.magicnum .db "MEM\0"
; layout info
    root.bank_first      .db $80
    root.bank_last       .db $FF
    root.page_first      .db $80
    root.page_last       .db $FF
    root.num_blocks_per_bank .db $80
    root.num_banks        .db $80
    root.num_blocks_total .dw $4000
; inode layout
    root.num_used_inodes  .dw $0005
    root.num_total_inodes .dw $4000
    root.num_free_inodes  .dw ($4000 - 5)
; directory
    root.entries.1.blockId .dw $0081
    root.entries.1.name .db "bar\0"
    root.entries.2.blockId .dw $0082
    root.entries.2.name .db "foo\0"
    root.entries.3.blockId .dw $0083
    root.entries.3.name .db "hello\0"
    root.entries.4.blockId .dw $0085
    root.entries.4.name .db "bee\0"
    root.entries.5.blockId .dw $0086
    root.entries.5.name .db "long\0"
    root.entries.6.blockId .dw $0000
.ENDST

; $0081 FILE: 'bar'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 5, 0
    inode_next .dw $0000
    file.directData .db "BAR!\n"
.ENDST

; $0082 FILE: 'foo'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 5, 0
    inode_next .dw $0000
    file.directData .db "FOO!\n"
.ENDST

; $0083 DIR: 'hello'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_DIR
    nlink .dw 1
    size .dw 1, 0
    inode_next .dw $0000
; directory
    dir.entries.1.blockId .dw $0084
    dir.entries.1.name .db "world\0"
    dir.entries.2.blockId .dw $0000
.ENDST

; $0084 FILE: 'world'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 15, 0
    inode_next .dw $0000
    file.directData .db "Hello, World!\n"
.ENDST

; $0085 FILE: 'bee'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 249, 0
    inode_next .dw $0000
    file.directBlocks:
        .dw $0180
    file.directData:
        .db "According to all known laws\n"
        .db "of aviation, there is no way\n"
        .db "that a bee should be able to\n"
        .db "fly. Its wings are too small\n"
        .db "to get its fat little body\n"
        .db "off the ground. The bee, of\n"
        .db "course, flies anyways."
.ENDST

; $0086 FILE: 'long'
.DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES
    type .dw FS_INODE_TYPE_FILE
    nlink .dw 1
    size .dw 192 + 256*16, 0
    inode_next .dw $0000
    file.directBlocks:
        .dw $0087
        .dw $0088
        .dw $0089
        .dw $008A
        .dw $008B
        .dw $008C
        .dw $008D
        .dw $008E
        .dw $008F
        .dw $0090
        .dw $0091
        .dw $0092
        .dw $0093
        .dw $0094
        .dw $0095
        .dw $0096
    file.directData:
        .db "BLK 00 LINE 000\n"
        .db "BLK 00 LINE 001\n"
        .db "BLK 00 LINE 002\n"
        .db "BLK 00 LINE 003\n"
        .db "BLK 00 LINE 004\n"
        .db "BLK 00 LINE 005\n"
        .db "BLK 00 LINE 006\n"
        .db "BLK 00 LINE 007\n"
        .db "BLK 00 LINE 008\n"
        .db "BLK 00 LINE 009\n"
        .db "BLK 00 LINE 00A\n"
        .db "BLK 00 LINE 00B\n"
.ENDST

; $0087
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 01 LINE 00C\n"
        .db "BLK 01 LINE 00D\n"
        .db "BLK 01 LINE 00E\n"
        .db "BLK 01 LINE 00F\n"
        .db "BLK 01 LINE 010\n"
        .db "BLK 01 LINE 011\n"
        .db "BLK 01 LINE 012\n"
        .db "BLK 01 LINE 013\n"
        .db "BLK 01 LINE 014\n"
        .db "BLK 01 LINE 015\n"
        .db "BLK 01 LINE 016\n"
        .db "BLK 01 LINE 017\n"
        .db "BLK 01 LINE 018\n"
        .db "BLK 01 LINE 019\n"
        .db "BLK 01 LINE 01A\n"
        .db "BLK 01 LINE 01B\n"
.ENDST

.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 02 LINE 01C\n"
        .db "BLK 02 LINE 01D\n"
        .db "BLK 02 LINE 01E\n"
        .db "BLK 02 LINE 01F\n"
        .db "BLK 02 LINE 020\n"
        .db "BLK 02 LINE 021\n"
        .db "BLK 02 LINE 022\n"
        .db "BLK 02 LINE 023\n"
        .db "BLK 02 LINE 024\n"
        .db "BLK 02 LINE 025\n"
        .db "BLK 02 LINE 026\n"
        .db "BLK 02 LINE 027\n"
        .db "BLK 02 LINE 028\n"
        .db "BLK 02 LINE 029\n"
        .db "BLK 02 LINE 02A\n"
        .db "BLK 02 LINE 02B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 03 LINE 02C\n"
        .db "BLK 03 LINE 02D\n"
        .db "BLK 03 LINE 02E\n"
        .db "BLK 03 LINE 02F\n"
        .db "BLK 03 LINE 030\n"
        .db "BLK 03 LINE 031\n"
        .db "BLK 03 LINE 032\n"
        .db "BLK 03 LINE 033\n"
        .db "BLK 03 LINE 034\n"
        .db "BLK 03 LINE 035\n"
        .db "BLK 03 LINE 036\n"
        .db "BLK 03 LINE 037\n"
        .db "BLK 03 LINE 038\n"
        .db "BLK 03 LINE 039\n"
        .db "BLK 03 LINE 03A\n"
        .db "BLK 03 LINE 03B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 04 LINE 03C\n"
        .db "BLK 04 LINE 03D\n"
        .db "BLK 04 LINE 03E\n"
        .db "BLK 04 LINE 03F\n"
        .db "BLK 04 LINE 040\n"
        .db "BLK 04 LINE 041\n"
        .db "BLK 04 LINE 042\n"
        .db "BLK 04 LINE 043\n"
        .db "BLK 04 LINE 044\n"
        .db "BLK 04 LINE 045\n"
        .db "BLK 04 LINE 046\n"
        .db "BLK 04 LINE 047\n"
        .db "BLK 04 LINE 048\n"
        .db "BLK 04 LINE 049\n"
        .db "BLK 04 LINE 04A\n"
        .db "BLK 04 LINE 04B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 05 LINE 04C\n"
        .db "BLK 05 LINE 04D\n"
        .db "BLK 05 LINE 04E\n"
        .db "BLK 05 LINE 04F\n"
        .db "BLK 05 LINE 050\n"
        .db "BLK 05 LINE 051\n"
        .db "BLK 05 LINE 052\n"
        .db "BLK 05 LINE 053\n"
        .db "BLK 05 LINE 054\n"
        .db "BLK 05 LINE 055\n"
        .db "BLK 05 LINE 056\n"
        .db "BLK 05 LINE 057\n"
        .db "BLK 05 LINE 058\n"
        .db "BLK 05 LINE 059\n"
        .db "BLK 05 LINE 05A\n"
        .db "BLK 05 LINE 05B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 06 LINE 05C\n"
        .db "BLK 06 LINE 05D\n"
        .db "BLK 06 LINE 05E\n"
        .db "BLK 06 LINE 05F\n"
        .db "BLK 06 LINE 060\n"
        .db "BLK 06 LINE 061\n"
        .db "BLK 06 LINE 062\n"
        .db "BLK 06 LINE 063\n"
        .db "BLK 06 LINE 064\n"
        .db "BLK 06 LINE 065\n"
        .db "BLK 06 LINE 066\n"
        .db "BLK 06 LINE 067\n"
        .db "BLK 06 LINE 068\n"
        .db "BLK 06 LINE 069\n"
        .db "BLK 06 LINE 06A\n"
        .db "BLK 06 LINE 06B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 07 LINE 06C\n"
        .db "BLK 07 LINE 06D\n"
        .db "BLK 07 LINE 06E\n"
        .db "BLK 07 LINE 06F\n"
        .db "BLK 07 LINE 070\n"
        .db "BLK 07 LINE 071\n"
        .db "BLK 07 LINE 072\n"
        .db "BLK 07 LINE 073\n"
        .db "BLK 07 LINE 074\n"
        .db "BLK 07 LINE 075\n"
        .db "BLK 07 LINE 076\n"
        .db "BLK 07 LINE 077\n"
        .db "BLK 07 LINE 078\n"
        .db "BLK 07 LINE 079\n"
        .db "BLK 07 LINE 07A\n"
        .db "BLK 07 LINE 07B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 08 LINE 07C\n"
        .db "BLK 08 LINE 07D\n"
        .db "BLK 08 LINE 07E\n"
        .db "BLK 08 LINE 07F\n"
        .db "BLK 08 LINE 080\n"
        .db "BLK 08 LINE 081\n"
        .db "BLK 08 LINE 082\n"
        .db "BLK 08 LINE 083\n"
        .db "BLK 08 LINE 084\n"
        .db "BLK 08 LINE 085\n"
        .db "BLK 08 LINE 086\n"
        .db "BLK 08 LINE 087\n"
        .db "BLK 08 LINE 088\n"
        .db "BLK 08 LINE 089\n"
        .db "BLK 08 LINE 08A\n"
        .db "BLK 08 LINE 08B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 09 LINE 08C\n"
        .db "BLK 09 LINE 08D\n"
        .db "BLK 09 LINE 08E\n"
        .db "BLK 09 LINE 08F\n"
        .db "BLK 09 LINE 090\n"
        .db "BLK 09 LINE 091\n"
        .db "BLK 09 LINE 092\n"
        .db "BLK 09 LINE 093\n"
        .db "BLK 09 LINE 094\n"
        .db "BLK 09 LINE 095\n"
        .db "BLK 09 LINE 096\n"
        .db "BLK 09 LINE 097\n"
        .db "BLK 09 LINE 098\n"
        .db "BLK 09 LINE 099\n"
        .db "BLK 09 LINE 09A\n"
        .db "BLK 09 LINE 09B\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 0A LINE 09C\n"
        .db "BLK 0A LINE 09D\n"
        .db "BLK 0A LINE 09E\n"
        .db "BLK 0A LINE 09F\n"
        .db "BLK 0A LINE 0A0\n"
        .db "BLK 0A LINE 0A1\n"
        .db "BLK 0A LINE 0A2\n"
        .db "BLK 0A LINE 0A3\n"
        .db "BLK 0A LINE 0A4\n"
        .db "BLK 0A LINE 0A5\n"
        .db "BLK 0A LINE 0A6\n"
        .db "BLK 0A LINE 0A7\n"
        .db "BLK 0A LINE 0A8\n"
        .db "BLK 0A LINE 0A9\n"
        .db "BLK 0A LINE 0AA\n"
        .db "BLK 0A LINE 0AB\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 0B LINE 0AC\n"
        .db "BLK 0B LINE 0AD\n"
        .db "BLK 0B LINE 0AE\n"
        .db "BLK 0B LINE 0AF\n"
        .db "BLK 0B LINE 0B0\n"
        .db "BLK 0B LINE 0B1\n"
        .db "BLK 0B LINE 0B2\n"
        .db "BLK 0B LINE 0B3\n"
        .db "BLK 0B LINE 0B4\n"
        .db "BLK 0B LINE 0B5\n"
        .db "BLK 0B LINE 0B6\n"
        .db "BLK 0B LINE 0B7\n"
        .db "BLK 0B LINE 0B8\n"
        .db "BLK 0B LINE 0B9\n"
        .db "BLK 0B LINE 0BA\n"
        .db "BLK 0B LINE 0BB\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 0C LINE 0BC\n"
        .db "BLK 0C LINE 0BD\n"
        .db "BLK 0C LINE 0BE\n"
        .db "BLK 0C LINE 0BF\n"
        .db "BLK 0C LINE 0C0\n"
        .db "BLK 0C LINE 0C1\n"
        .db "BLK 0C LINE 0C2\n"
        .db "BLK 0C LINE 0C3\n"
        .db "BLK 0C LINE 0C4\n"
        .db "BLK 0C LINE 0C5\n"
        .db "BLK 0C LINE 0C6\n"
        .db "BLK 0C LINE 0C7\n"
        .db "BLK 0C LINE 0C8\n"
        .db "BLK 0C LINE 0C9\n"
        .db "BLK 0C LINE 0CA\n"
        .db "BLK 0C LINE 0CB\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 0D LINE 0CC\n"
        .db "BLK 0D LINE 0CD\n"
        .db "BLK 0D LINE 0CE\n"
        .db "BLK 0D LINE 0CF\n"
        .db "BLK 0D LINE 0D0\n"
        .db "BLK 0D LINE 0D1\n"
        .db "BLK 0D LINE 0D2\n"
        .db "BLK 0D LINE 0D3\n"
        .db "BLK 0D LINE 0D4\n"
        .db "BLK 0D LINE 0D5\n"
        .db "BLK 0D LINE 0D6\n"
        .db "BLK 0D LINE 0D7\n"
        .db "BLK 0D LINE 0D8\n"
        .db "BLK 0D LINE 0D9\n"
        .db "BLK 0D LINE 0DA\n"
        .db "BLK 0D LINE 0DB\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 0E LINE 0DC\n"
        .db "BLK 0E LINE 0DD\n"
        .db "BLK 0E LINE 0DE\n"
        .db "BLK 0E LINE 0DF\n"
        .db "BLK 0E LINE 0E0\n"
        .db "BLK 0E LINE 0E1\n"
        .db "BLK 0E LINE 0E2\n"
        .db "BLK 0E LINE 0E3\n"
        .db "BLK 0E LINE 0E4\n"
        .db "BLK 0E LINE 0E5\n"
        .db "BLK 0E LINE 0E6\n"
        .db "BLK 0E LINE 0E7\n"
        .db "BLK 0E LINE 0E8\n"
        .db "BLK 0E LINE 0E9\n"
        .db "BLK 0E LINE 0EA\n"
        .db "BLK 0E LINE 0EB\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 0F LINE 0EC\n"
        .db "BLK 0F LINE 0ED\n"
        .db "BLK 0F LINE 0EE\n"
        .db "BLK 0F LINE 0EF\n"
        .db "BLK 0F LINE 0F0\n"
        .db "BLK 0F LINE 0F1\n"
        .db "BLK 0F LINE 0F2\n"
        .db "BLK 0F LINE 0F3\n"
        .db "BLK 0F LINE 0F4\n"
        .db "BLK 0F LINE 0F5\n"
        .db "BLK 0F LINE 0F6\n"
        .db "BLK 0F LINE 0F7\n"
        .db "BLK 0F LINE 0F8\n"
        .db "BLK 0F LINE 0F9\n"
        .db "BLK 0F LINE 0FA\n"
        .db "BLK 0F LINE 0FB\n"
.ENDST
.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "BLK 10 LINE 0FC\n"
        .db "BLK 10 LINE 0FD\n"
        .db "BLK 10 LINE 0FE\n"
        .db "BLK 10 LINE 0FF\n"
        .db "BLK 10 LINE 100\n"
        .db "BLK 10 LINE 101\n"
        .db "BLK 10 LINE 102\n"
        .db "BLK 10 LINE 103\n"
        .db "BLK 10 LINE 104\n"
        .db "BLK 10 LINE 105\n"
        .db "BLK 10 LINE 106\n"
        .db "BLK 10 LINE 107\n"
        .db "BLK 10 LINE 108\n"
        .db "BLK 10 LINE 109\n"
        .db "BLK 10 LINE 10A\n"
        .db "-END OF DIRECT-\n"
.ENDST

.ENDS

.SECTION "FS_Data_01" BANK $01 SLOT "ROM" ORGA $8000 FORCE

.DSTRUCT INSTANCEOF fs_memdev_direct_data_block VALUES
    data:
        .db "\n"
        .db "Because bees don't care what\n"
        .db "humans think is impossible.\n"
.ENDST

.ENDS