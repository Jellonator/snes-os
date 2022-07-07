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
    sta MEMSEL ; use FASTROM
    jml KernelInitialize2__

; Called by SNES' IRQ timer.
; In charge of process switching.
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
    ldx loword(kCurrentPID)
@find_ready:
    lda loword(kProcessNextIdTable),X
    tax
    lda loword(kProcessStatusTable),X
    cmp #PROCESS_READY
    bne @find_ready
; set found process to active
    stx loword(kCurrentPID)
; Switch to process
    txa
    asl
    tay
    rep #$10 ; 16b XY
    ldx loword(kProcessSPBackupTable),Y
    txs ; begin context switch
    pld
    plb
    ; rep #$10 ; 16b XY
    ply
    plx
    lda kNMITIMEN ; re-enable interrupts
    sta.l NMITIMEN
    rep #$20 ; 16b A
    pla ; finalize context switch
    rti

KernelInitialize2__:
    ; Disable rendering temporarily
    sep #$20 ; 8b A
    lda #%10000000
    sta.l INIDISP
    ; re-enable rendering
    lda #%00001111
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
    sta loword(kProcessStatusTable),X
    stz loword(kProcessMemPageIndexTable),X
    stz loword(kProcessMemPageCountTable),X
    stz loword(kProcessDirectPageIndexTable),X
    stz loword(kProcessDirectPageCountTable),X
    txa
    inc A
    sta loword(kProcessNextIdTable),X
    dec A
    dec A
    sta loword(kProcessPrevIdTable),X
    inx
    cpx #MAX_CONCURRENT_PROCESSES_COUNT
    bne @clear_process_loop
; setup null process list (first and last PID point to each other)
    lda #2
    sta loword(kProcessNextIdTable) + MAX_CONCURRENT_PROCESSES_COUNT - 1
    sta loword(kListNull)
    lda #MAX_CONCURRENT_PROCESSES_COUNT - 1
    sta loword(kProcessPrevIdTable) + 2
; Setup process 1
    lda #1
    sta loword(kCurrentPID)
    sta loword(kListActive)
    lda #PROCESS_READY
    sta loword(kProcessStatusTable + 1)
    stz loword(kProcessMemPageIndexTable + 1)
    lda #KERNEL_PAGES_USED
    sta loword(kProcessMemPageCountTable + 1)
    stz loword(kProcessDirectPageIndexTable + 1)
    lda #1
    sta loword(kProcessDirectPageCountTable + 1)
    sta loword(kProcessNextIdTable + 1)
    sta loword(kProcessPrevIdTable + 1)
; other initialization
    jsl KInitPrinter__
; re-enable IRQ/NMI
    rep #$20
    lda #128 ; choose close to center of screen to
    ; minimize the chance of overlap with NMI
    sta.l HTIME
    lda #160 ; start on first visible scanline
    sta.l VTIME
    sep #$20
    lda #%10100001
    sta.l NMITIMEN
    sta loword(kNMITIMEN)
    cli
; spawn test process
    sep #$20 ; 8b A
    pea 0  ; 0 args
    pea 64 ; 64b stack
    lda #bankbyte(KTestProgram__)
    pha
    pea loword(KTestProgram__)
    jsl kcreateprocess
    jsl kresumeprocess
    rep #$30 ; 16b A
    pla
    pla
    pla
    sep #$30 ; 8b A
    pla
; Finally, just become an infinite loop as process 1
    jmp KernelLoop__
KernelLoop__:
    jsl kreschedule
    jmp KernelLoop__

.ENDS