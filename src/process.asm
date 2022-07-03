.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KProcess" FREE

; Create a new process.
; PUSH order:
;   args       [ds] $0B...
;   nargs      [dw] $09
;   stack size [dw] $07
;   function   [dl] $04
kcreateprocess:
    sep #$30 ; 8b AXY
    .DisableInt__ ; [+1; 1]
    phb ; [+1; 2]
    .ChangeDataBank $7E
    ; first, get free PID
    ldx loword(kNextFreePID)
    ; TODO: failure when no more free PIDs
    ; remove X from null list
    ldy loword(kProcessNextIdTable),X ;   Y = X->next
    sty loword(kNextFreePID)
    lda loword(kProcessPrevIdTable),X ;   A = X->prev
    sta loword(kProcessPrevIdTable),Y ; X->next->prev = X->prev
    ldy loword(kProcessPrevIdTable),X ;   Y = X->prev
    lda loword(kProcessNextIdTable),X ;   A = X->next
    sta loword(kProcessNextIdTable),Y ; X->prev->next = X->next
    stz loword(kProcessNextIdTable),X ; X->next = 0
    lda loword(kProcessPrevIdTable)+0 ;   A = 0->prev
    sta loword(kProcessPrevIdTable),X ; X->prev = 0->prev
    tay
    txa
    sta loword(kProcessNextIdTable),Y ; 0->prev->next = X
    stx loword(kProcessPrevIdTable)+0 ; 0->prev = X
    ; set values
    lda #PROCESS_SUSPEND
    sta loword(kProcessStatusTable),X
    stz loword(kProcessFlagTable),X
    ; for now, just allocate DP as PID*4
    ; TODO: 'correct' stack allocation stretegy
    phx ; push PID [+1; 3]
    lda #4
    sta loword(kProcessDirectPageCountTable),X
    txa
    asl
    asl
    sta loword(kProcessDirectPageIndexTable),X
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
    sbc 3+$09,s ; subtract NARGS
    ; set X to index into SP backup table
    pha
    txa
    asl
    tax
    pla
    sta loword(kProcessSPBackupTable),X ; store SP
    tax ; X = top of stack
    lda 3+$04,s
    sta.w 11,X ; program counter
    sep #$20 ; 8b A
    lda 3+$06,s
    sta.w 13,X ; program bank
    lda #%00000000
    sta.w 10,X ; processor status
    lda #$7E
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
    tsx
    txa
    clc
    adc #$0B+3
    tax ; source = localSP+$0B+3
    lda 3+$09,s ; NARGS
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
    sep #$20 ; 8b A
    lda #PROCESS_READY
    sta.l kProcessStatusTable,X
    rtl

; reschedule current process
kreschedule:
    rep #$20
    pla ; increment return address
    inc A
    pha
    php
    sei
    jml KernelIRQ__

; Set process X's state to A
; A and X should be 8b
ksetprocessstate:
    sta.l kProcessStatusTable,X 
    rtl

; Set current process's state to A
; A and X should be 8b
ksetcurrentprocessstate:
    pha
    lda.l kActiveProcessId
    tax
    pla
    sta.l kProcessStatusTable,X
    rtl

.ENDS