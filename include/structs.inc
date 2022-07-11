.STRUCT processDirect_t
    memory dw ; allocated memory address
    memoryBank db ; allocated memory bank, useful if memory bank is changed
.ENDST

.STRUCT memblock_t
    mnext dw ; next block ptr ($0000 = null)
    mprev dw ; previous block ptr ($FFFF = null)
    mlength dw ; number of bytes in this block
    mPID db ; 0 if free, otherwise owned by PID
    _pad db ; pad to 8 bytes
.ENDST
