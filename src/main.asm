.include "base.inc"

; info during compile
.PRINT "Kernel memory end: $", HEX _kMemoryEnd, "\n"
.PRINT "Kernel memory used: $", HEX KERNEL_MEMORY_USED, "\n"
.PRINT "Kernel pages used: $", HEX KERNEL_PAGES_USED, "\n"

.BANK $00 SLOT "ROM"
.ORG $0000
.SECTION "KVectors" FORCE

KernelInitialize__:
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
    jsl KernelResetRegisters__
    lda #$01
    sta.l MEMSEL ; use FASTROM
    jml KernelInitialize2__

; Called by SNES' IRQ timer.
; In charge of process switching.
KernelBrk__:
KernelIRQ__:
    sei
    rep #$20 ; 16b A
    pha
; disable interrupts
    sep #$20 ; 8b A
    lda #%00000001
    sta.l NMITIMEN
    lda.l TIMEUP
    jml KernelIRQ2__ ; go to FASTROM section

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "MainCode" FREE

KernelIRQ2__:
; save context
    .ContextSave_NOA__
; begin
@entrypoint:
    sep #$30 ; 8b AXY
    .ChangeDataBank $7E
; find next READY process
    ldx.w loword(kCurrentPID)
    ; if current PID is null
    lda.w loword(kProcessStatusTable),X
    bne +
        ldx #1
    +:
@find_ready:
    lda.w loword(kProcessNextIdTable),X
    tax
    lda.w loword(kProcessStatusTable),X
    cmp #PROCESS_READY
    bne @find_ready
; set found process to active
    stx.w loword(kCurrentPID)
; Switch to process
    txa
    asl
    tay
    rep #$10 ; 16b XY
    ldx.w loword(kProcessSPBackupTable),Y
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
KernelInitialize2__:
    ; Disable rendering temporarily
    sep #$20 ; 8b A
    lda #%10001111
    sta.l INIDISP
    ; Enable joypad, disable interrupts
    sei
    lda #$01
    sta.l NMITIMEN
; clear lists
    stz.w loword(kListNull)
    stz.w loword(kListActive)
; clear data for all processes (1+)
    .ChangeDataBank $7E
    sep #$30 ; 8b AXY
    ldx #1
@clear_process_loop:
    lda #PROCESS_NULL
    sta.w loword(kProcessStatusTable),X
    stz.w loword(kProcessDirectPageIndexTable),X
    stz.w loword(kProcessDirectPageCountTable),X
    txa
    inc A
    sta.w loword(kProcessNextIdTable),X
    dec A
    dec A
    sta.w loword(kProcessPrevIdTable),X
    inx
    cpx #MAX_CONCURRENT_PROCESSES_COUNT
    bne @clear_process_loop
; setup null process list (first and last PID point to each other)
    lda #2
    sta.w loword(kProcessNextIdTable) + MAX_CONCURRENT_PROCESSES_COUNT - 1
    sta.w loword(kListNull)
    lda #MAX_CONCURRENT_PROCESSES_COUNT - 1
    sta.w loword(kProcessPrevIdTable) + 2
; Setup process 1
    lda #1
    sta.w loword(kCurrentPID)
    sta.w loword(kListActive)
    lda #PROCESS_READY
    sta.w loword(kProcessStatusTable + 1)
    stz.w loword(kProcessDirectPageIndexTable + 1)
    lda #1
    sta.w loword(kProcessDirectPageCountTable + 1)
    sta.w loword(kProcessNextIdTable + 1)
    sta.w loword(kProcessPrevIdTable + 1)
    lda #bankbyte(_init_name)
    sta.w loword(kProcessNameBankTable + 1)
    rep #$20
    lda #loword(_init_name)
    sta.w loword(kProcessNameTable + 2)
    sep #$20
; render initialization
    jsl KRenderInit__
    jsl KInitPrinter__
; mem init
    jsl KMemInit__
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
    jmp KernelLoop__
KernelLoop__:
    jsl kreschedule
    jmp KernelLoop__

.ENDS