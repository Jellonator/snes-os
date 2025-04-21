; Empty or invalid inode
.DEFINE FS_INODE_TYPE_EMPTY 0
; INode containing file data
.DEFINE FS_INODE_TYPE_FILE 1
; INode containing a directory
.DEFINE FS_INODE_TYPE_DIR 2
; INode which links to a separate device - currently unused
.DEFINE FS_INODE_TYPE_MOUNT 3
; INode for the root of a device.
.DEFINE FS_INODE_TYPE_ROOT 4
; INode for a 'stream', such as stdio
.DEFINE FS_INODE_TYPE_STREAM 5

; This OFT entry is currently in use
.DEFINE FS_TABLE_FLAG_OPEN $01
; This OFT entry is able to be read from
.DEFINE FS_TABLE_MODE_READ $80
; This OFT entry is able to be written to
.DEFINE FS_TABLE_MODE_WRITE $40

; Maximum length of filename
.DEFINE FS_MAX_FILENAME_LEN 14

; Device has files which can be read from
.DEFINE FS_DEVICE_MODE_READABLE $80
; Device has files which can be written to
.DEFINE FS_DEVICE_MODE_WRITABLE $40
; Device is able to create files
.DEFINE FS_DEVICE_MODE_FILE_CREATE $01
; Device is able to link files
.DEFINE FS_DEVICE_MODE_FILE_LINK $10
; Device is able to unlink files
.DEFINE FS_DEVICE_MODE_FILE_UNLINK $08

; File is able to be read from
.DEFINE FS_FILE_MODE_READABLE $80
; File is able to be written to
.DEFINE FS_FILE_MODE_WRITABLE $40

; Maximum number of open files
.DEFINE FS_OFT_SIZE 64
; Maximum number of device types
.DEFINE FS_DEVICE_TYPE_MAX_COUNT 8
; Maximum number of mounted devices
.DEFINE FS_DEVICE_INSTANCE_MAX_COUNT 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;         FILESYSTEM DEFINES         ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Defines a device - interaction with filesystem and file handles
.STRUCT fs_device_template_t
    ; name of the filesystem
    fsname ds 4
    ; Initialize filesystem
    ; void init([s16]fs_device_instance_t *dev);
    init dw
    ; Cleanup filesystem
    ; void free([s16]fs_device_instance_t *dev);
    free dw
    ; Get inode from path.
    ; The returned inode can be of any type, but is likely to be a FILE or DIRECTORY.
    ; RETURN:
    ;     X = NODE
    ;     Y = PARENT
    ; NODE may be NULL when PARENT is VALID, indicating that file does not exist but may be created.
    ; `path` is updated to tail in this scenario.
    ; The returned parent is always either a ROOT, or a DIR.
    ; [x16]inode *lookup([s16]fs_device_instance_t *dev, [s24]char *path);
    lookup dw
    ; Read data from the handle into the buffer.
    ; [a16]u16 read([s16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
    read dw
    ; Write data from buffer into file
    ; [a16]u16 write([s16]fs_handle_instance_t *fh, [s24]u8 *buffer, [s16]s16 nbytes)
    write dw
    ; Allocate inode
    ; [x16]u16 alloc([s16]fs_device_instance_t *dev, [s24]fs_inode_info_t* data);
    alloc dw
    ; Link inode to destination
    ; `dest` should be a DIRECTORY inode, `source` should be a FILE or DIR inode.
    ; `name` is the name that `source` will take on within `dest`.
    ; Returns `0` if link failed. Otherwise, returns `1`.
    ; [bool]u16 link([s16]fs_device_instance_t *dev, [s24]char *name, [s16]u16 source, [s16]u16 dest);
    link dw
    ; Unlink the inode from the given parent.
    ; Returns `0` if unlink failed. Otherwise, returns `1`.
    ; `dest` should be the DIR parent of `source`.
    ; [bool]u16 unlink([s16]fs_device_instance_t *dev, [s16]u16 source, [u16]u16 dest);
    unlink dw
    ; Get info about an inode
    ; void info([s16]fs_device_instance_t *dev, [s16]u16 inode_id, [s24]fs_inode_info_t *data)
    info dw
.ENDST

; Info about an inode, usually read from a device.
.STRUCT fs_inode_info_t
    type dw
    mode dw
    size dsw 2
.ENDST

; Handle to an open file
.STRUCT fs_handle_instance_t
    state db
    fileptr dw
    device dw
    inode dw
.ENDST

; Mounted device instance
.STRUCT fs_device_instance_t
    ; device template - defines functionality
    template dw
    ; mount point
    mount_name ds FS_MAX_FILENAME_LEN
    ; custom data, depends on device
    data ds 16
.ENDST

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   FILESYSTEM SPECIFIC STUFF BELOW  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.DEFINE FSMEM_DIR_MAX_INODE_COUNT 12 ; matches 192 bytes of file
.DEFINE FSMEM_DIR_INODESIZE (FS_MAX_FILENAME_LEN+2)
.ASSERT ((FSMEM_DIR_INODESIZE) & (FSMEM_DIR_INODESIZE-1)) == 0
; this will never change; inodes are always page-aligned
.DEFINE FSMEM_INODE_SIZE 256

; directory entry
.STRUCT fs_memdev_direntry_t ; SIZE 16
    blockId dw ; if blockId == 0, then end.
    name ds FS_MAX_FILENAME_LEN
.ENDST

; inode structure
; inodes form a linked list, to make allocating and releasing them fast.
.STRUCT fs_memdev_inode_t SIZE 256
    ; This inode's type
    type dw
    ; Number of links to this inode
    nlink dw
    ; FILE - Number of bytes stored in this inode
    ; DIR - Number of files linked to this inode
    size dsw 2
    ; Next available inode
    inode_next dw
    _reserved dsw 3
    ; FS_INODE_TYPE_FILE
    .UNION file
        ; reserved data; maybe double-indirect blocks?
        ; would be (4iN × 128iN/iN × 128iN/iN × 256) = 16 MiB, or entire addressable space.
        ; which kinda works out to be honest.
        ; though, problem here, is that fs_handle_instance_t.fileptr is only up to 64KiB.
        _reserved dsw 4
        ; indirect blocks storing inode IDs of data
        indirectBlocks dsw 4 ; up to 128KiB data (4iN × 128iN/iN × 256B/iN)
        ; direct blocks of data
        directBlocks dsw 16 ; up to 4KiB of data (16iN × 256B/iN)
        ; first 192 bytes of data are stored directly in the inode
        directData ds 192 ; up to 192B of data
    ; FS_INODE_TYPE_DIR
    .NEXTU dir
        _reserved ds 48
        ; list of directory entries
        ; may be expanded with the use of directBlocks later
        entries INSTANCEOF fs_memdev_direntry_t FSMEM_DIR_MAX_INODE_COUNT
    ; FS_INODE_TYPE_ROOT
    .NEXTU root
    ; magicnumber for comparison
        magicnum ds 4
    ; layout info
        bank_first db
        bank_last db
        page_first db
        page_last db
        num_blocks_per_bank db
        num_banks db
        num_blocks_total dw
        mode dw
        _pad ds 6
    ; inode layout
        ; number of used inodes
        num_used_inodes dw
        ; total number of inodes
        num_total_inodes dw
        ; number of free inodes
        num_free_inodes dw
    ; directory
        _reserved ds 22
        entries INSTANCEOF fs_memdev_direntry_t FSMEM_DIR_MAX_INODE_COUNT
    .ENDU
.ENDST

; layout of a direct data block (just 256b of data)
.STRUCT fs_memdev_direct_data_block SIZE 256
    data ds 256
.ENDST

; layout of an indirect data block (128 inodes)
.STRUCT fs_memdev_indirect_data_block SIZE 256
    inodes dsw 128
.ENDST

; data used to mount a device
.STRUCT fs_device_instance_mem_data_t SIZE 16
    bank_first db
    bank_last db
    page_first db
    page_last db
    blocks_per_bank db
    num_banks db
    blocks_total dw
    mode dw
.ENDST