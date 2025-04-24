.include "base.inc"

.BASE $00

; First 8B of zeropage are reserved and may be modified by system functions.
.RAMSECTION "ZP" BANK 0 SLOT "SharedMemory" ORGA $0000 FORCE
    kReservedZP ds 8
.ENDS

.RAMSECTION "Shared" BANK 0 SLOT "SharedMemory" ORGA $0008 FORCE
    kRendererAddr dl
    kRendererProcess db
    kRendererDP dw
    kRendererDB db
    ; temporary memory for kernel processes which want to use the direct page.
    ; only use if interrupts are disabled.
    ; be careful not to use too much, as this space is also used by the init process' stack.
    kTmpBuffer ds 64
.ENDS

.RAMSECTION "7E" BANK $7E SLOT "ExtraMemory" ORGA $2000 ALIGN 256 FORCE
    kDirectPageMask ds (DP_BLOCK_COUNT / 8)
    kCurrentPID db ; active process's PID
    kNMITIMEN db ; stores current value of NMITEN (read-only) hardware register
    kNextFreeMemoryBlock dw ; address of next free memory block
; Process info stored in tables
    kProcTabStatus ds KPROC_NUM
    kProcTabFlag ds KPROC_NUM
    kProcTabDirectPageIndex ds KPROC_NUM
    kProcTabDirectPageCount ds KPROC_NUM
    kProcTabStackSave dsw KPROC_NUM
    kProcTabNameBank ds KPROC_NUM
    kProcTabNamePtr dsw KPROC_NUM
; queueinfo
    kQueueTabNext ds KQUEUE_NUM
    kQueueTabPrev ds KQUEUE_NUM
; terminal info
    kTermPrintVMEMPtr dw ; index of VMEM pointer
    kTermOffY dw ; Y-offset of terminal, used for scrolling
    kTermBufferCount dw ; number of characters to be printed
    kTermBufferLoop db ; if non-zero: write bytes from kTermBufferCount to
    .ALIGN $0100
    kSpriteTable INSTANCEOF object_t 128
    kSpriteTableHigh dsb 32
; buffer size, then from 0 to kTermBufferCount
    .ALIGN $0100
    kTermBuffer ds KTERM_MAX_BUFFER_SIZE ; text to be added
    kTempBuffer ds 256 ; generic temporary buffer
; semaphore info
    kSemTabCount ds KSEM_NUM
; joypad inputs
    kJoy1Raw dw
    kJoy1Press dw
    kJoy1Held dw
    kMouse1X db
    kMouse1Y db
    kMouse1Raw dw
    kMouse1Press dw
    kMouse1Held dw
    kInput1Device dw
    kMouseDoingInitialize dw
; Window info
    ; Owner of each desktop tile (WINDOW ID)
    kWindowTileTabOwner ds 32*32
    ; Whether each tile is dirty
    kWindowTileTabDirty ds 32*32
    ; List of dirty tiles
    kWindowDirtyTileList dsw 32*32
    kWindowNumDirtyTiles dw
    ; Owner of each window (PID)
    kWindowTabProcess ds MAX_WINDOW_COUNT+1
    ; Position of each window
    kWindowNumWindows dw
    kWindowTabPosX ds MAX_WINDOW_COUNT+1
    kWindowTabPosY ds MAX_WINDOW_COUNT+1
    kWindowTabWidth ds MAX_WINDOW_COUNT+1
    kWindowTabHeight ds MAX_WINDOW_COUNT+1
    ; Window render function addresses
    kWindowTabRenderFuncBank ds MAX_WINDOW_COUNT+1
    kWindowTabRenderFuncPage ds MAX_WINDOW_COUNT+1
    kWindowTabRenderFuncLow ds MAX_WINDOW_COUNT+1
    ; Draw Buffer (character data to be copied to VRAM)
    .ALIGN $0100
    kWindowDrawBuffer ds WINDOW_DRAW_BUFFER_TOTAL_SIZE
    kWindowDrawBufferSize dw
    kWindowDrawBufferTargetAddr dsw WINDOW_DRAW_BUFFER_ELEMENTS
    kWindowDrawBufferSourceAddr dsw WINDOW_DRAW_BUFFER_ELEMENTS
    ; Tile Buffer (tile data to be copied to VRAM)
    kWindowTileBufferSize dw
    kWindowTileBuffer INSTANCEOF window_tile_buffer_t (32*32)
    ; Window order (front -> back)
    kWindowOrder ds MAX_WINDOW_COUNT+1
; filesystem
    ; list of available device templates
    kfsDeviceTemplateTable dsl FS_DEVICE_TYPE_MAX_COUNT
    kfsDeviceInstanceTable INSTANCEOF fs_device_instance_t FS_DEVICE_INSTANCE_MAX_COUNT
    kfsFileHandleTable INSTANCEOF fs_handle_instance_t FS_OFT_SIZE
    ; kFsRootDevice INSTANCEOF fs_device_descriptor_t
    ; kFsFileTable INSTANCEOF fs_filetable_t FS_OFT_SIZE
; end
    ; kfsVolatileFilesystemReservation ds $4000
.ENDS
