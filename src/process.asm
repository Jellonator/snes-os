.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KProcess" FREE

; Create a new process.
; PUSH order:
;   args       [ds] $0E...
;   nargs      [dw] $0C
;   stack size [dw] $0A
;   name       [dl] $07
;   function   [dl] $04
; Returns:
;   PID: X [db], = 0 on error
kcreateprocess:
    sep #$30 ; 8b AXY
    .DisableInt__ ; [+1; 1]
    phb ; [+1; 2]
    .ChangeDataBank $7E
    ; get next PID
    ldx #KQID_FREELIST
    jsl kdequeue
    cpy #0
    bne +
        ldx #0
        rtl
    +:
    tyx
    ; set values
    lda #PROCESS_SUSPEND ; start suspended
    sta.w loword(kProcTabStatus),X
    stz.w loword(kProcTabFlag),X
    lda 2+$09,s
    sta.w loword(kProcTabNameBank),X
    phx ; +1 [3]
    txa
    asl
    tax
    rep #$20
    lda 3+$07,s
    sta.w loword(kProcTabNamePtr),X
    sep #$20
    plx ; -1 [2]
    ; for now, just allocate DP as PID*4
    ; TODO: 'correct' stack allocation stretegy
    phx ; push PID [+1; 3]
    lda #4
    sta.w loword(kProcTabDirectPageCount),X
    txa
    asl
    asl
    sta.w loword(kProcTabDirectPageIndex),X
    rep #$30 ; 16b AXY
    and #$00FF
    ; DP index -> DP
    asl
    asl
    asl
    asl
    asl
    tay ; Y = DP
; setup stack and its values
    ; D  2 1,2
    ; B  1 3
    ; Y  2 4,5
    ; X  2 6,7
    ; A  2 8,9
    ; P  1 10
    ; PC 3 11,12,[13]
    ; DP -> SP (= DP + DPsize - 1 - StackSize)
    clc
    adc #(32*4)-1 - 13 ; +{size of DP}-1 -{register store size}
    sec
    sbc 3+$0C,s ; subtract NARGS
    ; set X to index into SP backup table
    pha
    txa
    asl
    tax
    pla
    sta.w loword(kProcTabStackSave),X ; store SP
    tax ; X = top of stack
    lda 3+$04,s
    sta.w 11,X ; program counter
    sep #$20 ; 8b A
    lda 3+$06,s
    sta.w 13,X ; program bank
    lda #%00000000
    sta.w 10,X ; processor status
    lda #$7F
    sta.w 3,X ; data bank
    rep #$20 ; 16b A
    tya
    sta.w 1,X ; direct page
    ; values of A,X,Y don't matter for now
; set up process arguments
    txa
    clc
    adc #13+1
    tay ; dest = newSP+{register store size}
    tsc
    clc
    adc #$0E+3
    tax ; source = localSP+$0B+3
    lda 3+$0C,s ; NARGS
    beq +
    dec A
    mvn $00,$00 ; copy args from local stack to new stack
    +:
; end
    sep #$30 ; 8b AXY
    plx ; return X = pid [-1]
    plb ; [-1]
    .RestoreInt__ ; [-1]
    rtl

; Resume process in X
kresumeprocess:
    sep #$30 ; 8b AXY
    .DisableInt__
    lda #PROCESS_READY
    sta.l kProcTabStatus,X
    txy
    jsl kremoveitem
    ldx #1 ; enqueue after init process
    jsl kenqueue
    .RestoreInt__
    rtl

; Suspend process in X
process_suspend:
    sep #$30
    .DisableInt__
    lda #PROCESS_WAIT_SEM
    sta.l kProcTabStatus,X
    txy
    jsl kremoveitem
    .RestoreInt__
    rtl

; wait for NMI signal
pwaitfornmi:
    sep #$30
    .DisableInt__
    lda.l kCurrentPID
    tax
    lda #PROCESS_WAIT_NMI
    sta.l kProcTabStatus,X
    txy
    jsl kremoveitem
    ldx #KQID_NMILIST
    jsl kenqueue
    .RestoreInt__
    jmp kreschedule

; reschedule current process
kreschedule:
    brk
    nop
    rtl

; ; Set process X's state to A
; ; A and X should be 8b
; ksetprocessstate:
;     sta.l kProcessStatusTable,X 
;     rtl

; ; Set current process's state to A
; ; A should be 8b
; ksetcurrentprocessstate:
;     sep #$30
;     pha
;     lda.l kCurrentPID
;     tax
;     pla
;     sta.l kProcessStatusTable,X
;     rtl

; Kill process with ID in X
kkill:
    .INDEX 8
    sep #$20 ; 8b A
    phb
    .ChangeDataBank $7E
    .DisableInt__
    ; set status to PROCESS_NULL
    stz.w loword(kProcTabStatus),X
    ; remove process from queues
    txy
    jsl kremoveitem
    ; add to free list
    ldx #KQID_FREELIST
    jsl kenqueue
    tyx
    ; if current process is renderer, then return renderer to OS
    sep #$30 ; 8b AXY
    cpx.w loword(kRendererProcess)
    bne @skipremoverenderer
        phx
        php
        jsl KRenderInit__
        plp
        plx
    @skipremoverenderer:
; free memory used by process
    phx ; push ID
    rep #$10 ; 16b XY
    .ChangeDataBank $7F
    ldx #$0000
    @memloop:
        sep #$20 ; 8b A
        lda.w memblock_t.mPID,X
        cmp $01,s
        bne +
            jsl kmemfreeblock
        +:
        ldy.w memblock_t.mnext,X
        tyx
        cpx #0
        bne @memloop
    .ChangeDataBank $7E
    sep #$30 ; 8b AXY
    plx ; pull ID
    .RestoreInt__
    plb
    rtl

exit:
    sep #$30
    lda.l kCurrentPID
    tax
    jsl kkill
    jsl kreschedule

.ENDS