.DEFINE FS_BLOCK_SIZE 256

.DEFINE FS_INODE_TYPE_FILE 1
.DEFINE FS_INODE_TYPE_DIR 2
.DEFINE FS_INODE_TYPE_MOUNT 3

.DEFINE FS_MAX_FILENAME_LEN 14

.DEFINE FS_DEVICE_NULL 0
.DEFINE FS_DEVICE_SRAM 1 ; SRAM device
.DEFINE FS_DEVICE_ROM 2 ; ROM device

.DEFINE FS_TABLE_FLAG_OPEN $01

.DEFINE FS_TABLE_MODE_READ $80
.DEFINE FS_TABLE_MODE_WRITE $40
.DEFINE FS_TABLE_MODE_RDWR $C0

.DEFINE FS_OFT_SIZE 64
.DEFINE FS_DEVICE_TYPE_MAX_COUNT 8
.DEFINE FS_DEVICE_INSTANCE_MAX_COUNT 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;         FILESYSTEM DEFINES         ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Defines a device - interaction with filesystem and file handles
.STRUCT fs_device_template_t
    ; name of the filesystem
    fsname ds 4
    ; get inode from path
    lookup dw
.ENDST

.STRUCT fs_device_instance_t
    ; device template - defines functionality
    template dw
    ; mount point
    mount_name ds 14
    ; custom data, depends on device
    data ds 16
.ENDST

.STRUCT fs_handle_instance_t
    state db
    fileptr dw
    device dw
    inode dw
.ENDST

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   FILESYSTEM SPECIFIC STUFF BELOW  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; ; device descriptor object
; .STRUCT fs_device_descriptor_t
;     device db ; device ID
;     devptr dw ; e.g. for in-memory devices: memory location
; .ENDST

; ; in-memory device (SRAM/ROM/RAM) header
; ; header: 32B
; ; root dir: 160B
; ; mask: 64B
; .STRUCT fs_mem_header_t ; SIZE 256
;     magicnum ds 4 ; magic number for filesystem
;     device db
;     flags db
;     nBanks dw ; number of banks
;     nBlocksPerBank dw ; number of blocks in each bank
;     nBlocks dw ; = nBanks * nBlocksPerBank
;     nFreeMaskBytes dw ; number of bytes used for free mask (up to 8K)
;     nFreeMaskBlocks dw ; number of excess blocks used for mask.
;                    ; If 0, then mask is entirely contained in filesystem_t
;     firstInodeBlock dw ; First inode block
;     nInodeBlocks dw ; number of inode blocks
;     nUsedInodeBlocks dw ; number of used inodes
;     firstDataBlock dw ; first block used for data
;     nDataBlocks dw ; number of data blocks
;     nUsedDataBlocks dw ; number of used data blocks
; .ENDST
; .define fs_mem_header_t.rootDir 32 ; 160 bytes for root directory info
; ; 8 directory entries

; .define fs_mem_header_t.maskData 192 ; 64 bytes for mask (only 32b needed per entire 64K bank)
; ; theoretically need up to 32 blocks of 256 bytes to represent entire 24bit addressable space

; ; directory entry
; .STRUCT fs_mem_direntry_t ; SIZE 16
;     blockId dw ; if blockId == 0, then end.
;     name ds 14 ; if name[0] == $1F, then blockId is next direntry.
;     ; Entries after null entry this one will be ignored, so it should be last.
; .ENDST

; ; INODE entry
; .STRUCT fs_mem_inode_t
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
;         dirent INSTANCEOF fs_mem_direntry_t 15
;     .ENDU
; .ENDST

; ; filetable entry
; .STRUCT fs_filetable_t
;     state db ; state + flags; 0 = available
;     device INSTANCEOF fs_device_descriptor_t
;     inode dw ; inode ID
;     fileptr dw ; file pointer
; .ENDST