.DEFINE FS_BLOCK_SIZE 256

.DEFINE FS_INODE_TYPE_EMPTY 0
.DEFINE FS_INODE_TYPE_FILE 1
.DEFINE FS_INODE_TYPE_DIR 2
.DEFINE FS_INODE_TYPE_MOUNT 3
.DEFINE FS_INODE_TYPE_ROOT 4

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
    ; NODE may be NULL when PARENT is VALID, indicating that file may be created.
    ; `path` is updated, in this scenario.
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
    ; `dest` should be a DIRECTORY inode, `source` should be a FILE inode.
    ; `name` is the name that `source` will take on within `dest`.
    ; Returns `0` if link failed. Otherwise, returns `1`.
    ; [bool]u16 link([s16]fs_device_instance_t *dev, [s24]char *name, [s16]u16 source, [s16]u16 dest);
    link dw
    ; Unlink the inode at the given path
    ; Returns `0` if unlink failed. Otherwise, returns `1`.
    ; [bool]u16 unlink([s16]fs_device_instance_t *dev, [s24]char* path);
    unlink dw
    ; Get info about an inode
    ; void info([s16]fs_device_instance_t *dev, [s16]u16 inode_id, [s24]fs_inode_info_t *data)
    info dw
.ENDST

.STRUCT fs_inode_info_t
    type dw
    size dsw 2
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

.STRUCT fs_device_instance_mem_data_t SIZE 16
    bank_first db
    bank_last db
    page_first db
    page_last db
    blocks_per_bank db
    num_banks db
    blocks_total dw
.ENDST

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   FILESYSTEM SPECIFIC STUFF BELOW  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; directory entry
.STRUCT fs_memdev_direntry_t ; SIZE 16
    blockId dw ; if blockId == 0, then end.
    name ds 14
.ENDST

; inode structure
; inodes form a linked list, to make allocating and releasing them fast.
.STRUCT fs_memdev_inode_t SIZE 256
    type dw
    nlink dw
    size dsw 2
    inode_next dw
    _reserved dsw 3
    .UNION file
        ; first 192 bytes of data are stored directly in the inode
        directData ds 192 ; up to 192B of data
        ; direct blocks of data
        directBlocks dsw 16 ; up to 4K of data
        ; indirect blocks storing inode IDs of data
        indirectBlocks dsw 4 ; up to 128K data
        _reserved dsw 4
    .NEXTU dir
        ; list of directory entries
        _reserved ds 16
        dirent INSTANCEOF fs_memdev_direntry_t 14
    .ENDU
.ENDST

; inode* = $0100*inodeId

; root structure
.STRUCT fs_memdev_root_t SIZE 256
; header 'type' info from inode
    type dw
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
; inode layout
    ; number of used inodes
    num_used_inodes dw
    ; total number of inodes
    num_total_inodes dw
    ; number of free inodes
    num_free_inodes dw
    ; first free inode in linked list
    inode_next_free dw
; directory
    _reserved ds 10
    dirent INSTANCEOF fs_memdev_direntry_t 14
.ENDST