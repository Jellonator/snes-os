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
    ; set stack to $001F (top of first direct page)
    ldx #$001F
    txs
    ; Initialize registers
    jsl KernelResetRegisters__
    lda #$01
    sta MEMSEL ; use FASTROM
    jml KernelInitialize2__

; Called by SNES' IRQ timer.
; In charge of process switching.
KernelIRQ__:
    rep #$20 ; 16b A
    pha
    sep #$20 ; 8b A
; disable interrupts
    lda #%00000001
    sta.l NMITIMEN
; save context
    .ContextSave_NOA__
; begin
    .ChangeDataBank $7E
    sep #$30 ; 8b AXY
    lda.l TIMEUP
; set active process to READY
    lda loword(kActiveProcessId)
    tax
    lda #PROCESS_READY
    sta loword(kProcessStatusTable),X
; find next READY process
@find_ready:
    lda loword(kProcessNextIdTable),X
    tax
    lda loword(kProcessStatusTable),X
    cmp #PROCESS_READY
    bne @find_ready
; set found process to active
    stx loword(kActiveProcessId)
    lda #PROCESS_ACTIVE
    sta loword(kProcessStatusTable),X
; Switch to process
    txa
    asl
    tay
    ldx loword(kProcessSPBackupTable),Y
    txs ; begin context switch
    pld
    plb
    rep #$10 ; 16b XY
    ply
    plx
    lda kNMITIMEN ; re-enable interrupts
    sta.l NMITIMEN
    rep #$20 ; 16b A
    pla ; finalize context switch
    rti

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "MainCode" FREE

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
; clear data for processes 1+
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
    stz loword(kProcessNextIdTable),X
    stz loword(kProcessPrevIdTable),X
    inx
    cpx #MAX_CONCURRENT_PROCESSES_COUNT
    bne @clear_process_loop
; Setup process 0
    stz loword(kActiveProcessId)
    lda #PROCESS_READY
    sta loword(kProcessStatusTable + 0)
    stz loword(kProcessMemPageIndexTable + 0)
    lda #KERNEL_PAGES_USED
    sta loword(kProcessMemPageCountTable + 0)
    stz loword(kProcessDirectPageIndexTable + 0)
    lda #1
    sta loword(kProcessDirectPageCountTable + 0)
    stz loword(kProcessNextIdTable + 0)
    stz loword(kProcessPrevIdTable + 0)
; other initialization
    jsl KInitPrinter__
; re-enable IRQ/NMI
    rep #$20
    lda #24 ; start just after hblank
    sta.l HTIME
    lda #0 ; start on first visible scanline
    sta.l VTIME
    sep #$20
    lda #%10110001
    sta.l NMITIMEN
    sta loword(kNMITIMEN)
    cli

; Finally, just become an infinite loop as process 0
    .DEFINE __idx $03
    sep #$30 ; 8b AXY
    stz.b __idx
    jmp KernelLoop__
KernelLoop__:
    wai
    sep #$30 ; 8b AXY
    ldx #0
    -:
    lda.l __teststr,X
    beq +
    phx
    jsl kputc
    sep #$30 ; 8b AXY
    plx
    inx
    bra -
    +:
    jmp KernelLoop__

__teststr:
    .DB "Hello, world!\0"

; Context switch; change to stack pointer in X
ContextSwitchTo__:
    txs
    pld
    plb
    ply
    plx
    pla
    rti

.ENDS