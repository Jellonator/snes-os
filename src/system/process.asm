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
procCreate:
    sep #$30 ; 8b AXY
    .DisableInt__ ; [+1; 1]
    phb ; [+1; 2]
    .ChangeDataBank $7E
    ; get next PID
    ldx #KQID_FREELIST
    jsl queuePop
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
procResume:
    sep #$30 ; 8b AXY
    .DisableInt__
    lda #PROCESS_READY
    sta.l kProcTabStatus,X
    txy
    jsl queueRemoveItem
    ldx #1 ; enqueue after init process
    jsl queuePush
    .RestoreInt__
    rtl

; Suspend process in X
procSuspend:
    sep #$30
    .DisableInt__
    lda #PROCESS_SUSPEND
    sta.l kProcTabStatus,X
    txy
    jsl queueRemoveItem
    .RestoreInt__
    rtl

; wait for NMI signal
procWaitNMI:
    sep #$30
    .DisableInt__
    lda.l kCurrentPID
    tax
    lda #PROCESS_WAIT_NMI
    sta.l kProcTabStatus,X
    txy
    jsl queueRemoveItem
    ldx #KQID_NMILIST
    jsl queuePush
    .RestoreInt__
    jmp procReschedule

; reschedule current process
procReschedule:
    brk
    nop
    rtl

; Kill process with ID in X
procKill:
    .INDEX 8
    sep #$20 ; 8b A
    stx.b $04
    phb
    .ChangeDataBank $7E
    .DisableInt__
    ; set status to PROCESS_NULL
    stz.w loword(kProcTabStatus),X
    ; remove process from queues
    ldy.b $04
    jsl queueRemoveItem
    ; add to free list
    ldx #KQID_FREELIST
    ldy.b $04
    jsl queuePush
    ; if current process is renderer, then return renderer to OS
    sep #$30 ; 8b AXY
    ldx.b $04
    cpx.w loword(kRendererProcess)
    bne @skipremoverenderer
        php
        jsl kRendererInit__
        plp
        ldx.b $04
    @skipremoverenderer:
; free memory used by process
    rep #$10 ; 16b XY
    .ChangeDataBank $7F
    ldx #$0000
    @memloop:
        sep #$20 ; 8b A
        ldy.w memblock_t.mnext,X
        sty.b $00
        lda.w memblock_t.mPID,X
        cmp.b $04
        bne +
            jsl memFreeBlock__
        +:
        ldx.b $00
        cpx #0
        bne @memloop
    .ChangeDataBank $7E
    sep #$30 ; 8b AXY
    ldx.b $04
    .RestoreInt__
    plb
    rtl

procExit:
    sep #$30
    lda.l kCurrentPID
    tax
    jsl procKill
    jsl procReschedule

.ENDS