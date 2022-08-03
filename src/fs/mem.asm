.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "FSMem" FREE

_magicNum:
    .db "FMD9"

; Initialize memory device
; Push order:
;   bank [db]
;   page [db]
;   nbanks [db], number of banks
;   npages [db], number of pages per bank
fsMemInit:
    rep #$20 ; 16b A
    lda.l _magicNum
    sta.l fs_mem_header_t.magicnum,X
    lda.l _magicNum+2
    sta.l fs_mem_header_t.magicnum+2,X
    lda #FS_DEVICE_SRAM
    sta.l fs_mem_header_t.device,X


.ENDS
