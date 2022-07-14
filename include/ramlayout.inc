; OS memory info starts at $7E2000
.ENUM $7E2000
    kMemoryPageMask ds ((MEM_BLOCK_COUNT / 8) * 2) ; two banks
    kDirectPageMask ds (DP_BLOCK_COUNT / 8)
    kCurrentPID db ; active process's PID
    kListNull db ; null process list
    kListActive db ; active process list
    kNMITIMEN db ; stores current value of NMITEN (read-only) hardware register
    kNextFreeMemoryBlock dw ; address of next free memory block
; Process info stored in tables
    kProcessStatusTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessFlagTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessMemPageIndexTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessMemPageCountTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessDirectPageIndexTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessDirectPageCountTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessNextIdTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessPrevIdTable ds MAX_CONCURRENT_PROCESSES_COUNT
    kProcessSPBackupTable dsw MAX_CONCURRENT_PROCESSES_COUNT
; terminal info
    kTermPrintVMEMPtr dw ; index of VMEM pointer
    kTermOffY dw ; Y-offset of terminal, used for scrolling
    kTermBufferCount dw ; number of characters to be printed
    kTermBufferLoop db ; if non-zero: write bytes from kTermBufferCount to
; buffer size, then from 0 to kTermBufferCount
    kTermBuffer ds KTERM_MAX_BUFFER_SIZE ; text to be added
    kTempBuffer ds 256 ; generic temporary buffer
; semaphore info
    kSemCountTable ds KSEM_NUM
    kSemPIDTable ds KSEM_NUM
    _kMemoryEnd db
; joypad inputs
    kJoy1Raw dw
    kJoy1Press dw
    kJoy1Held dw
.ENDE

.DEFINE kMemList $7F0000

; certain OS memory values must be contained in bank 0, namely jump pointers
.ENUM $7E0008
; Render info
    kRendererAddr dl
    kRendererProcess db
    kRendererDP dw
    kRendererDB db
.ENDE

.DEFINE KERNEL_MEMORY_USED loword(_kMemoryEnd)
.DEFINE KERNEL_PAGES_USED ((KERNEL_MEMORY_USED + 256 - 1) >> 8)

; local process info
.ENUM $00
    localinfo INSTANCEOF processDirect_t
    _localInfoEnd db
.ENDE