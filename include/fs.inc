.DEFINE FS_BLOCK_SIZE 256

.DEFINE FS_INODE_TYPE_FILE 1
.DEFINE FS_INODE_TYPE_DIR 2
.DEFINE FS_MAX_FILENAME_LEN 14

.DEFINE FS_DEVICE_NULL 0
.DEFINE FS_DEVICE_SRAM 1

.DEFINE FS_HFLAG_RDONLY $01 ; readonly filesystem, e.g. one defined in ROM

; .STRUCT fs_sram_header_t SIZE 256
;     magicnum ds 4 ; magic number for filesystem
;     device db
;     flags db
;     nBanks dw ; number of banks
;     nBlocksPerBank dw ; number of blocks in each bank
;     nBlocks dw ; = nBanks * nBlocksPerBank
;     nFreeMaskBytes dw ; number of bytes used for free mask (up to 8K)
;     nMaskBlocks dw ; number of blocks used for mask. If 0, then mask is entirely contained in filesystem_t
;     firstInodeBlock dw ; First inode block
;     nInodeBlocks dw ; number of inode blocks
;     nUsedInodeBlocks dw ; number of used inodes
;     firstDataBlock dw ; first block used for data
;     nDataBlocks dw ; number of data blocks
;     nUsedDataBLocks dw ; number of used data blocks
; .ENDST
; .define filesystem_sram_t.rootDir 64 ; 128 bytes for root directory info
; ; theoretically need up to 32 blocks of 256 bytes to represent entire 24bit addressable space
; .define filesystem_sram_t.maskData 64 ; 64 bytes for mask (only 32b needed per entire 64K bank)

; .STRUCT fs_sram_direntry_t SIZE 16
;     blockId dw ; if blockId == 0, then end.
;     name ds 14 ; if name[0] == $1F, then blockId is next direntry.
;     ; Entries after null entry this one will be ignored, so it should be last.
; .ENDST

; .STRUCT fs_sram_inode_t SIZE 256
;     type dw
;     nlink dw
;     size dw
;     _reserved dsw 5
;     .UNION file
;         ; first 192 bytes of data are stored directly in the inode
;         directData ds 192 ; up to 192B of data
;         ; direct blocks of data
;         directBlocks dsw 16 ; up to 4K of data
;         ; indirect blocks storing inode IDs of data
;         indirectBlocks dsw 4 ; up to 128K data
;         _reserved dsw 4
;     .NEXTU dir
;         ; list of directory entries
;         dirent INSTANCEOF fs_sram_directory_t 15
;     .ENDU
; .ENDST