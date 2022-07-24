.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KQueue" FREE

; clear queue X
queueClear:
    sep #$30
    txa
    sta.l kQueueTabNext,X ; X->next = X
    sta.l kQueueTabPrev,X ; X->prev = X
    rtl

; free queue X
queueFree:
    sep #$30
    lda #0
    sta.l kQueueTabNext,X
    sta.l kQueueTabPrev,X
    rtl

; Insert process Y to the tail of queue X
queuePush:
    sep #$30
    phb
    .ChangeDataBank $7E
    .DisableInt__
; begin
    txa
    sta.w loword(kQueueTabNext),Y ; qtNext[pid] = X
    lda.w loword(kQueueTabPrev),X ; A = qtPrev[X]
    sta.w loword(kQueueTabPrev),Y ; qtPrev[pid] = qtPrev[X]
    sta.b $00
    tya                           ; A = pid
    sta.w loword(kQueueTabPrev),X ; qtPrev[X] = pid
    ldx.b $00                     ; X = qtPrev[X]
    sta.w loword(kQueueTabNext),X ; qtNext[qtPrev[X]] = pid
; end
    .RestoreInt__
    plb
    rtl

; Remove first process in queue X
; returns PID8 in Y
queuePop:
    sep #$30
    phb
    .ChangeDataBank $7E
    .DisableInt__
; begin
    lda.w loword(kQueueTabNext),X ; A = first pid
    sta.b $00
    cpx.b $00
    bne @notempty
        ldy #0
        .RestoreInt__
        plb
        rtl
@notempty:
    tay ; Y = pid
    lda.w loword(kQueueTabNext),Y ; A = next
    sta.b $02
    lda.w loword(kQueueTabPrev),Y ; A = prev
    ldy.b $02 ; Y = next
    sta.w loword(kQueueTabPrev),Y
    tay ; Y = prev
    lda.b $02 ; A = next
    sta.w loword(kQueueTabNext),Y
    ldy.b $00 ; Y = pid
    lda #0
    sta.w loword(kQueueTabNext),Y
    sta.w loword(kQueueTabPrev),Y
; end
    .RestoreInt__
    plb
    rtl

; remove PID Y from any queues it may be in
queueRemoveItem:
    sep #$30
    phb
    .ChangeDataBank $7E
    .DisableInt__
; begin
    lda.w loword(kQueueTabNext),Y ; A = next
    beq @end ; not in any queues, end
    sty.b $00
    sta.b $02
    lda.w loword(kQueueTabPrev),Y ; A = prev
    ldy.b $02 ; Y = next
    sta.w loword(kQueueTabPrev),Y
    tay ; Y = prev
    lda.b $02 ; A = next
    sta.w loword(kQueueTabNext),Y
    ldy.b $00 ; Y = pid
    lda #0
    sta.w loword(kQueueTabNext),Y
    sta.w loword(kQueueTabPrev),Y
@end:
; end
    .RestoreInt__
    plb
    rtl

.ENDS
