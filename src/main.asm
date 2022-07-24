.include "base.inc"

; info during compile
.PRINT "Kernel memory end: $", HEX _kMemoryEnd, "\n"
.PRINT "Kernel memory used: $", HEX KERNEL_MEMORY_USED, "\n"
.PRINT "Kernel pages used: $", HEX KERNEL_PAGES_USED, "\n"

.BANK $00 SLOT "ROM"
.ORG $0000
.SECTION "KVectors" FORCE

kInitialize__:
    ; Disabled interrupts
    sei
    ; Change to native mode
    clc
    xce
    ; Binary mode (decimal mode off), X/Y 16 bit
    rep #$18
    ; set stack for init process
    ldx #$003F
    txs
    ; Initialize registers
    jsl kResetRegisters__
    lda #$01
    sta.l MEMSEL ; use FASTROM
    jml kInitialize2__

; Called by SNES' IRQ timer.
; In charge of process switching.
kBrk__:
kIRQ__:
    sei
    rep #$20 ; 16b A
    pha
; disable interrupts
    sep #$20 ; 8b A
    lda #%00000001
    sta.l NMITIMEN
    lda.l TIMEUP
    jml kIRQ2__ ; go to FASTROM section

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "MainCode" FREE

kIRQ2__:
; save context
    .ContextSave_NOA__
; begin
@entrypoint:
    sep #$30 ; 8b AXY
    .ChangeDataBank $7E
; find next READY process
    ldx.w loword(kCurrentPID)
    ; if current PID is not READY, change next PID to 1
    lda.w loword(kProcTabStatus),X
    cmp #PROCESS_READY
    beq +
        ldx #1
    +:
    lda.w loword(kQueueTabNext),X
; set found process to active
    sta.w loword(kCurrentPID)
; Switch to process
    asl
    tay
    rep #$10 ; 16b XY
    ldx.w loword(kProcTabStackSave),Y
    txs ; begin context switch
    pld
    plb
    ; rep #$10 ; 16b XY
    ply
    plx
    lda.l kNMITIMEN ; re-enable interrupts
    sta.l NMITIMEN
    rep #$20 ; 16b A
    pla ; finalize context switch
    rti

_init_name: .db "init\0"
kInitialize2__:
    ; Disable rendering temporarily
    sep #$30 ; 8b A
    lda #%10001111
    sta.l INIDISP
    ; Enable joypad, disable interrupts
    sei
    lda #$01
    sta.l NMITIMEN
; clear lists
    ldx #KQID_NMILIST
    jsl queueClear
; clear data for all processes (1+)
    .ChangeDataBank $7E
    sep #$30 ; 8b AXY
    ldx #1
@clear_process_loop:
    stz.w loword(kProcTabStatus),X ; status = null
    stz.w loword(kProcTabDirectPageIndex),X
    stz.w loword(kProcTabDirectPageCount),X
    txa
    inc A
    sta.w loword(kQueueTabNext),X ; next = X+1
    dec A
    dec A
    sta.w loword(kQueueTabPrev),X ; prev = X-1
    inx
    cpx #KPROC_NUM
    bne @clear_process_loop
; setup null process list
    lda #2
    sta.w loword(kQueueTabNext) + KQID_FREELIST
    lda #KPROC_NUM-1
    sta.w loword(kQueueTabPrev) + KQID_FREELIST
    lda #KQID_FREELIST
    sta.w loword(kQueueTabPrev) + 2
    sta.w loword(kQueueTabNext) + KPROC_NUM-1
; Setup process 1
    lda #1
    sta.w loword(kCurrentPID)
    sta.w loword(kProcTabDirectPageCount + 1)
    sta.w loword(kQueueTabNext + 1)
    sta.w loword(kQueueTabPrev + 1)
    lda #PROCESS_READY
    sta.w loword(kProcTabStatus + 1)
    stz.w loword(kProcTabDirectPageIndex + 1)
    lda #bankbyte(_init_name)
    sta.w loword(kProcTabNameBank + 1)
    rep #$20
    lda #loword(_init_name)
    sta.w loword(kProcTabNamePtr + 2)
    sep #$20
; render initialization
    jsl kRendererInit__
    jsl vPrinterInit
; mem init
    jsl kMemInit__
    rep #$20
    stz.w loword(kJoy1Held)
    stz.w loword(kJoy1Press)
    stz.w loword(kJoy1Raw)
; re-enable IRQ/NMI
    rep #$20
    lda #128 ; choose close to center of screen to
    ; minimize the chance of overlap with NMI
    sta.l HTIME
    lda #110 ; middle of screen
    sta.l VTIME
    sep #$20
    lda #%10110001
    sta.l NMITIMEN
    sta.w loword(kNMITIMEN)
    cli
; re-enable rendering
    lda #%00001111
    sta.l INIDISP
; spawn test process
    ; .CreateReadyProcess KTestProgram__, 64, 0
    .CreateReadyProcess os_shell, 64, 0, os_shell@n
; Finally, just become an infinite loop as process 1
    - jsl procReschedule
    jmp -

.ENDS