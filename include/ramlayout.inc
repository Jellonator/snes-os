; OS memory info starts at $7E2000
.ENUM $7E2000
    kMemoryPageMask ds ((MEM_BLOCK_COUNT / 8) * 2) ; two banks
    kDirectPageMask ds (DP_BLOCK_COUNT / 8)
    kActiveProcessId db
    kNMITIMEN db ; stores current value of NMITEN hardware register
    ; NMITEN is a read-only register
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
    _kMemoryEnd db
.ENDE

.DEFINE KERNEL_MEMORY_USED loword(_kMemoryEnd)
.DEFINE KERNEL_PAGES_USED ((KERNEL_MEMORY_USED + 256 - 1) >> 8)

; local process info
.ENUM $00
    localinfo INSTANCEOF processDirect_t
    _localInfoEnd db
.ENDE