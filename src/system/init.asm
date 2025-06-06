.include "base.inc"

.BANK $00 SLOT "ROM"
.ORG $0000
.SECTION "KInitVector" SEMIFREE

kInitialize__:
    ; Disabled interrupts
    sei
    ; Change to native mode
    clc
    xce
    ; Binary mode (decimal mode off), X/Y 16 bit
    rep #$18
    ; set stack for init process
    ldx #$007F
    txs
    ; Initialize registers
    jsl kResetRegisters__
    lda #$01
    sta.l MEMSEL ; use FASTROM
    jml kInitialize2__

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "KInit" SEMIFREE

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
; clear key blocks of memory
    .ClearWRam kQueueTabNext KQUEUE_NUM*2
    .ClearWRam kSemTabCount KSEM_NUM
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
    sta.w loword(kQueueTabNext + 1)
    sta.w loword(kQueueTabPrev + 1)
    lda #4
    sta.w loword(kProcTabDirectPageCount + 1)
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
; filesystem init
    jsl kfsInit__
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
    .CreateReadyProcess os_shell, 64, 0, os_shell@n
; Finally, just become an infinite loop as process 1
    - jsl procReschedule
    jmp -

kResetRegisters__:
	sep #$30  ; X,Y,A are 8 bit numbers
	lda #$8F  ; screen off, full brightness
	sta $2100 ; brightness + screen enable register 
	stz $2101 ; Sprite register (size + address in VRAM) 
	stz $2102 ; Sprite registers (address of sprite memory [OAM])
	stz $2103 ;    ""                       ""
	stz $2105 ; Mode 0, = Graphic mode register
	stz $2106 ; noplanes, no mosaic, = Mosaic register
	stz $2107 ; Plane 0 map VRAM location
	stz $2108 ; Plane 1 map VRAM location
	stz $2109 ; Plane 2 map VRAM location
	stz $210A ; Plane 3 map VRAM location
	stz $210B ; Plane 0+1 Tile data location
	stz $210C ; Plane 2+3 Tile data location
	stz $210D ; Plane 0 scroll x (first 8 bits)
	stz $210D ; Plane 0 scroll x (last 3 bits) #$0 - #$07ff
	lda #$FF  ; The top pixel drawn on the screen isn't the top one in the tilemap, it's the one above that.
	sta $210E ; Plane 0 scroll y (first 8 bits)
	sta $2110 ; Plane 1 scroll y (first 8 bits)
	sta $2112 ; Plane 2 scroll y (first 8 bits)
	sta $2114 ; Plane 3 scroll y (first 8 bits)
	lda #$07  ; Since this could get quite annoying, it's better to edit the scrolling registers to fix this.
	sta $210E ; Plane 0 scroll y (last 3 bits) #$0 - #$07ff
	sta $2110 ; Plane 1 scroll y (last 3 bits) #$0 - #$07ff
	sta $2112 ; Plane 2 scroll y (last 3 bits) #$0 - #$07ff
	sta $2114 ; Plane 3 scroll y (last 3 bits) #$0 - #$07ff
	stz $210F ; Plane 1 scroll x (first 8 bits)
	stz $210F ; Plane 1 scroll x (last 3 bits) #$0 - #$07ff
	stz $2111 ; Plane 2 scroll x (first 8 bits)
	stz $2111 ; Plane 2 scroll x (last 3 bits) #$0 - #$07ff
	stz $2113 ; Plane 3 scroll x (first 8 bits)
	stz $2113 ; Plane 3 scroll x (last 3 bits) #$0 - #$07ff
	lda #$80  ; increase VRAM address after writing to $2119
	sta $2115 ; VRAM address increment register
	stz $2116 ; VRAM address low
	stz $2117 ; VRAM address high
	stz $211A ; Initial Mode 7 setting register
	stz $211B ; Mode 7 matrix parameter A register (low)
	lda #$01
	sta $211B ; Mode 7 matrix parameter A register (high)
	stz $211C ; Mode 7 matrix parameter B register (low)
	stz $211C ; Mode 7 matrix parameter B register (high)
	stz $211D ; Mode 7 matrix parameter C register (low)
	stz $211D ; Mode 7 matrix parameter C register (high)
	stz $211E ; Mode 7 matrix parameter D register (low)
	sta $211E ; Mode 7 matrix parameter D register (high)
	stz $211F ; Mode 7 center position X register (low)
	stz $211F ; Mode 7 center position X register (high)
	stz $2120 ; Mode 7 center position Y register (low)
	stz $2120 ; Mode 7 center position Y register (high)
	stz $2121 ; Color number register ($0-ff)
	stz $2123 ; BG1 & BG2 Window mask setting register
	stz $2124 ; BG3 & BG4 Window mask setting register
	stz $2125 ; OBJ & Color Window mask setting register
	stz $2126 ; Window 1 left position register
	stz $2127 ; Window 2 left position register
	stz $2128 ; Window 3 left position register
	stz $2129 ; Window 4 left position register
	stz $212A ; BG1, BG2, BG3, BG4 Window Logic register
	stz $212B ; OBJ, Color Window Logic Register (or,and,xor,xnor)
	sta $212C ; Main Screen designation (planes, sprites enable)
	stz $212D ; Sub Screen designation
	stz $212E ; Window mask for Main Screen
	stz $212F ; Window mask for Sub Screen
	lda #$30
	sta $2130 ; Color addition & screen addition init setting
	stz $2131 ; Add/Sub sub designation for screen, sprite, color
	lda #$E0
	sta $2132 ; color data for addition/subtraction
	stz $2133 ; Screen setting (interlace x,y/enable SFX data)
	stz $4200 ; Enable V-blank, interrupt, Joypad register
	lda #$FF
	sta $4201 ; Programmable I/O port
	stz $4202 ; Multiplicand A
	stz $4203 ; Multiplier B
	stz $4204 ; Multiplier C
	stz $4205 ; Multiplicand C
	stz $4206 ; Divisor B
	stz $4207 ; Horizontal Count Timer
	stz $4208 ; Horizontal Count Timer MSB (most significant bit)
	stz $4209 ; Vertical Count Timer
	stz $420A ; Vertical Count Timer MSB
	stz $420B ; General DMA enable (bits 0-7)
	stz $420C ; Horizontal DMA (HDMA) enable (bits 0-7)
	stz $420D ; Access cycle designation (slow/fast rom)
	rtl

.ENDS
