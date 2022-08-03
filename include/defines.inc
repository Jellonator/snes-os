; Joy buttons
.DEFINE JOY_A $0080
.DEFINE JOY_X $0040
.DEFINE JOY_L $0020
.DEFINE JOY_R $0010
.DEFINE JOY_B $8000
.DEFINE JOY_Y $4000
.DEFINE JOY_SELECT $2000
.DEFINE JOY_START $1000
.DEFINE JOY_UP $0800
.DEFINE JOY_DOWN $0400
.DEFINE JOY_LEFT $0200
.DEFINE JOY_RIGHT $0100
.DEFINE JOY_ID $000F

; Memory layout info
.DEFINE KPROC_NUM 64
.DEFINE DP_BLOCK_COUNT 256
.DEFINE DP_BLOCK_SIZE 32 ; $2000 = DP_BLOCK_COUNT * DP_BLOCK_SIZE

.DEFINE MEM_BLOCK_SIZE 256 ; 1 page
.DEFINE MEM_BLOCK_COUNT 256 ; number of pages in $7F

; Process data
.DEFINE PROCESS_NULL 0 ; in free list
.DEFINE PROCESS_READY 1 ; in ready list
.DEFINE PROCESS_SUSPEND 2 ; not in any list
.DEFINE PROCESS_WAIT_NMI 3 ; process is waiting for NMI
.DEFINE PROCESS_WAIT_SEM 4 ; process is waiting on semaphore
; special property: (PROCESS_WAIT_NMI & $7F) == PROCESS_READY

.DEFINE PROCFLAG_BANK $01 ; 0 = bank $7E, 1 = bank $7F

; Interrupt data
.DEFINE KINTERRUPT_IRQ %00000001
.DEFINE KINTERRUPT_NMI %00000010

; Terminal info
.DEFINE KTERM_MAX_BUFFER_SIZE 784

; Semaphore info
.DEFINE KSEM_PID_FREE $80 ; top bit of PID means slot is free
.DEFINE KSEM_NUM 64

; queue info
.DEFINE KQUEUE_NUM 255
.DEFINE KQID_PROC 0 ; first queue reserved for processes
.DEFINE KQID_SEM KPROC_NUM ; first queue reserved for semaphores
; preset queue IDs
.ENUMID (KPROC_NUM + KSEM_NUM)
.ENUMID KQID_FREELIST ; List used for inactive processes
.ENUMID KQID_NMILIST ; List used for processing waiting for NMI
.ENUMID KQID_FIRST ; First freely allocatable QID
.DEFINE KQID_READYLIST 1 ; List used for ready processes, also the init process
