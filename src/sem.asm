.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KSem" FREE

; create a semaphore, returns SID8 in X
; initializes semaphore to A
semcreate:
    sep #$30 ; 8b AXY
    pha
    .DisableInt__
    ldx #KQID_SEM-1 ; SID8 is actually synonymous with QID8, for efficiency sake
    ; TODO: fail if semtab is full
    - inx ; start at 0
    lda.l kQueueTabNext,X
    bne - ; try next if not null
    .RestoreInt__
    ; clear queue
    txa
    sta.l kQueueTabNext,X ; X->next = X
    sta.l kQueueTabPrev,X ; X->prev = X
    ; set count
    pla
    sta.l kSemTabCount-KQID_SEM,X
    rtl

; wait for semaphore in X
semwait:
    sep #$30
    phb
    .ChangeDataBank $7E
    .DisableInt__
; begin
    dec.w loword(kSemTabCount-KQID_SEM),X
    bpl +
    ; --count < 0, block
        ; insert PID into queue
        lda.w loword(kCurrentPID)
        tay
        jsl kenqueue
        ; suspend
        tyx
        jsl process_suspend
        .RestoreInt__
        jsl kreschedule
        ; resume
        plb
        rtl
    +:
; end
    sep #$30
    .RestoreInt__
    plb
    rtl

semsignal:
    sep #$30
    phb
    .ChangeDataBank $7E
    .DisableInt__
; begin
    lda.w loword(kSemTabCount-KQID_SEM),X
    bcs +
        jsl kdequeue
        tyx
        jsl kresumeprocess
    +:
    inc.w loword(kSemTabCount-KQID_SEM),X
; kSemTabCount
    sep #$30
    .RestoreInt__
    plb
    rtl
    rtl

; Frees the semaphore in X
semdelete:
    sep #$30
; kill waiting processes
@looprm:
    jsl kdequeue
    cpy #0
    beq @endrm
    phx
    tyx
    jsl kkill
    plx
    bra @looprm
@endrm:
    jsl kdelqueue
    rtl

.ENDS