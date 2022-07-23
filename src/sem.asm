.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KSem" FREE

; create a semaphore, returns SID8 in X
; initializes semaphore to A
semcreate:
;     sep #$30 ; 8b AXY
;     pha
;     .DisableInt__
;     ldx #0
;     -:
;     ; TODO: fail if semtab is full
;     inx ; start at 1
;     lda.l kSemPIDTable,X
;     bpl - ; if top bit is 0, try again
;     lda #0
;     sta.l kSemCountTable,X
;     .RestoreInt__
;     pla
;     sta.l kSemCountTable,X
    rtl

semwait:
    rtl

semsignal:
    rtl

; ; Frees the semephore in X
semdelete:
;     sep #$20
;     lda #80
;     sta.l kSemPIDTable,X
;     ; TODO: free waiting processes
    rtl

.ENDS