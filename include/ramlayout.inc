; OS memory info starts at $7E2000
.ENUM $7E2000
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
; buffer size, then from 0 to kTermBufferCount
    kTermBuffer ds KTERM_MAX_BUFFER_SIZE ; text to be added
    kTempBuffer ds 256 ; generic temporary buffer
; semaphore info
    kSemTabCount ds KSEM_NUM
; joypad inputs
    kJoy1Raw dw
    kJoy1Press dw
    kJoy1Held dw
; end
    _kMemoryEnd db
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
