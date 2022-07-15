.include "base.inc"

.DEFINE PAGE_SIZE 256
.DEFINE MEMBLOCK_SIZE 5
.DEFINE MIN_MEM_ADDR $7F0000
.DEFINE MAX_MAM_ADDR $7FFFFF

.BANK $01 SLOT "ROM"
.SECTION "KMem" FREE

KMemInit__:
    rep #$20
    lda #$0000
    sta.l kMemList + memblock_t.mnext
    sta.l kMemList + memblock_t.mPID
    sta.l kNextFreeMemoryBlock
    lda #$FFFF
    sta.l kMemList + memblock_t.mprev
    rtl

; Allocate bytes
; push order:
;   nbytes [dw] $04
; Returns:
;   X: the pointer (null if error)
;   capacity [dw]: the number of bytes in the block
memalloc:
; disable interrupts
    sep #$20 ; 8b A
    .DisableInt__ ; +1 (1)
; change data bank
    rep #$30 ; 16b AXY
; round nbytes to MEMBLOCK_SIZE
    lda 1+$04,s
    clc
    adc #MEMBLOCK_SIZE-1
    ; and #$FFF8
    sta.l DIVU_DIVIDEND
    sep #$20
    lda #MEMBLOCK_SIZE
    sta.l DIVU_DIVISOR
    rep #$20 ; 3
    phb ; +1 (2)
    .ChangeDataBank $7F ; 13
    lda.l DIVU_QUOTIENT
    asl
    asl
    clc
    adc.l DIVU_QUOTIENT
    sta 2+$04,s
; begin
    lda.l kNextFreeMemoryBlock
    tay
    bra @enterloop
; find free memory block with enough bytes
@continue:
    lda.w memblock_t.mnext,Y ; get next memory block
    beq @error ; error: reached end of memory list
    tay
    lda.w memblock_t.mPID,Y
    beq @continue ; block is not free, continue
@enterloop:
    lda.w memblock_t.mnext,Y
    sty $00 ; $00 = block1
    sec
    sbc $00
    sec
    sbc #MEMBLOCK_SIZE
    cmp 2+$04,s
    bcc @continue ; mlength < nbytes, continue
; found memory block
    beq @exactmem
; not exact mem, split block:
    sta $02 ; $02 = mlength
    sec
    sbc #MEMBLOCK_SIZE
    sbc 2+$04,s
    beq @exactmemext ; block1.mlength == 8+nbytes, just use the entire block instead
    tya
    clc
    adc #MEMBLOCK_SIZE
    adc 2+$04,s
    tax ; X = block2/free block
    ; set up block2
    lda.w memblock_t.mnext,Y
    sta.w memblock_t.mnext,X   ; block2->next = block1->next
    sta.w memblock_t.mPID,X    ; block2->mPID = 0
    tya
    sta.w memblock_t.mprev,X   ; block2->prev = block1
    ; modify block 1
    lda 2+$04,s
    txa
    sta.w memblock_t.mnext,Y   ; block1->next = block2
    sta.l kNextFreeMemoryBlock ; kNextFreeMemoryBlock = block2
    lda.l kCurrentPID
    and #$00FF
    sta.w memblock_t.mPID,Y    ; block1->mPID = kCurrentPID
    ; set next free block
    tya
    clc
    adc #MEMBLOCK_SIZE
    tax
    bra @end
@exactmemext:
    ; modify nbytes to match size of found block
    lda.w $02
    sta 2+$04,s
@exactmem:
; Exact mem, use entire block
    ; update next free memory block
    tyx
    @@loop:
        lda.w memblock_t.mnext,X
        beq @@endloop
        tax
        lda.w memblock_t.mPID,X
        bne @@loop
        txa
    @@endloop:
        sta.l kNextFreeMemoryBlock
    ; set X to return and end
    tya
    clc
    adc #MEMBLOCK_SIZE
    tax
    bra @end
; end
@error:
    ldx #0
@end:
    ; restore bank
    plb ; -1 (1)
    ; restore interrupts
    sep #$20 ; 8b A
    .RestoreInt__ ; -1 (0)
    rtl

; Free memory block X
kmemfreeblock:
; disable interrupts
    sep #$20 ; 8b A
    .DisableInt__ ; +1 (1)
; change data bank
    rep #$30 ; 16b AXY
    phb ; +1 (2)
    .ChangeDataBank $7F
; mark as free
    stz.w memblock_t.mPID,X
; merge with prev if it is free (and not null)
    ldy.w memblock_t.mprev,X
    cpy #$FFFF
    beq +
    lda.w memblock_t.mPID,Y
    bne +
        ; perform merge
        ; X = current
        ; Y = prev
        lda.w memblock_t.mnext,X
        sta.w memblock_t.mnext,Y
        tyx
    +:
; merge with next if it is free
    ldy.w memblock_t.mnext,X
    beq +
    lda.w memblock_t.mPID,Y
    bne +
        ; perform merge
        ; X = current
        ; Y = next
        lda.w memblock_t.mnext,Y
        sta.w memblock_t.mnext,X
    +:
; kNextFreeMemoryBlock = min(kNextFreeMemoryBlock, X)
    txa
    cmp.l kNextFreeMemoryBlock
    bcs +
    sta.l kNextFreeMemoryBlock
    +:
; end
    ; restore bank
    plb ; -1 (1)
    ; restore interrupts
    sep #$20 ; 8b A
    .RestoreInt__ ; -1 (0)
    rtl

; free memory at X
memfree:
    rep #$30 ; 16b AXY
    txa
    sec
    sbc #MEMBLOCK_SIZE
    tax
    jmp kmemfreeblock

; Memory change owner
; Change owner of memory in X to PID A
; A must be 8b and X must be 16b
memchown:
    .INDEX 16
    .ACCU 8
    dex
    sta.l $7F0000,X
    inx
    rtl

; debug memory print
KPrintMemoryDump__:
; disable interrupts
    sep #$20 ; 8b A
    .DisableInt__ ; +1 (1)
; change data bank
    rep #$30 ; 16b AXY
    phb ; +1 (2)
    
; begin
    ldy #$0000 ; mem block ptr in $7F
@loop:
    ldx #loword(kTempBuffer) ; string buffer in $7E
    ; write PID
    .ChangeDataBank $7F
    sep #$20 ; 8b A
    lda.w memblock_t.mPID,Y
    phy
    .ChangeDataBank $7E
    jsl writeptrb
    ; write space
    lda #' '
    sta.w $0000,X
    inx
    ; write pointer start
    rep #$20 ; 16b A
    lda $01,s
    clc
    adc #MEMBLOCK_SIZE
    jsl writeptrw
    ; write colon
    pha
    sep #$20 ; 8b A
    lda #':'
    sta.w $0000,X
    inx
    ; write pointer end
    .ChangeDataBank $7F
    rep #$20 ; 16b A
    pla
    sec
    sbc #1
    clc
    ply
    phy
    ; adc.w memblock_t.mlength,Y
    lda.w memblock_t.mnext,Y
    dec A
    .ChangeDataBank $7E
    jsl writeptrw
    ; write end
    ; sep #$20
    lda #'\n'
    sta.w $0000,X
    ; inx
    ; stz $0000,X
    ; write to print
    ldy #loword(kTempBuffer)
    jsl kputstring
    .ChangeDataBank $7F
    rep #$20 ; 16b A
    ply
    lda.w memblock_t.mnext,Y
    tay
    bne @loop
; end
    ; restore bank
    plb ; -1 (1)
    ; restore interrupts
    sep #$20 ; 8b A
    .RestoreInt__ ; -1 (0)
    rtl

.ENDS