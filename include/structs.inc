.STRUCT processDirect_t
    memory dw ; allocated memory address
    memoryBank db ; allocated memory bank, useful if memory bank is changed
.ENDST

.STRUCT memblock_t
    mnext dw ; next block ptr ($0000 = null)
    mprev dw ; previous block ptr ($FFFF = null)
    mPID db ; 0 if free, otherwise owned by PID
.ENDST

.STRUCT command_t
    plLabel dl
    plName dl
    ; _pad dw
.ENDST
