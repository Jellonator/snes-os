.include "base.inc"

.BANK $02 SLOT "ROM"
.SECTION "ShellAssets" FREE

ShellTextPalette__:
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 31, 31, 31
    .DCOLOR_RGB5 20, 16, 22
    .DCOLOR_RGB5 11, 11, 11
; selected color
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 31, 31, 31
    .DCOLOR_RGB5 24, 20, 12
    .DCOLOR_RGB5  0,  0,  0
; unselected color
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 12, 12, 12
    .DCOLOR_RGB5 11, 10, 11
    .DCOLOR_RGB5  0,  0,  0

ShellBackPalette__:
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 20, 16, 22
    .DCOLOR_RGB5  8,  8,  8
    .DCOLOR_RGB5  6,  6,  6

ShellBackgroundData__:
    ; line 0-1
    .dsw 64 $0000
    ; line 2
    .dw $0000, $0010
    .dsw 28 $0011
    .dw $0012, $0000
    ; line 3-9
    .REPT 7
    .dw $0000, $0020
    .dsw 28 $0021
    .dw $0022, $0000
    .ENDR
    ; line 10
    .dw $0000, $0030
    .dsw 28 $0031
    .dw $0032, $0000
    ; line 11-31
    .REPT 21
    .dsw 32 $0000
    .ENDR

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "Shell" FREE

; tile data addresses; granularity is (X % $0400) words
.DEFINE BG1_SHELLTEXT_TILE_BASE_ADDR $0400
.DEFINE BG2_SHELLBACK_TILE_BASE_ADDR $0800
.DEFINE BG4_DISPTEXT_TILE_BASE_ADDR $0000
; tile character addresses; granularity is (X % $1000) words
.DEFINE BG2_SHELLBACK_CHAR_BASE_ADDR $2000
.DEFINE BG4_DISPTEXT_CHAR_BASE_ADDR $1000
; BG4 refers to data from kprint.asm

.DEFINE DEADZONE_LEFT 2 ; screen offset from left
.DEFINE MAX_LINE_WIDTH 28 ; maximum of 28 characters per row
.DEFINE ROW_START 25 ; row to start writing to

.ENUMID 0
.ENUMID STATE_HIDDEN
.ENUMID STATE_LOWER
.ENUMID STATE_UPPER
.ENUMID STATE_CAPS
.ENUMID STATE_SYMBOLS

_char_addresses:
    .dw __ShellSymLower
    .dw __ShellSymLower
    .dw __ShellSymUpper
    .dw __ShellSymUpper
    .dw _ShellSymSymbols

.DEFINE SHFLAG_UPDATE_CHARS $80

; variables
.ENUM $08
    bState db
    bSelectPos db
    bUpdateFlags db
    ; wVMEMPtr dw
    ; string buffer
    wCharLinePos dw
    wLenStrBuf dw
    pwStrBuf dw
    ; draw buffer; 4-byte instructions of VMEM addr[dw]+Value[dw] pairs
    wLenDrawBuf dw
    pwDrawBuf dw
.ENDE

_shell_hide_ui:
    ; show only BG4 on main screen
    lda #%00001000
    sta.l SCRNDESTM
    stz.b bState
    rts

_shell_show_ui:
    sep #$30 ; 8b AXY
    ; Show BGs 1, 2, and 4
    lda #%00001011
    sta.l SCRNDESTM
    lda #STATE_LOWER
    sta.b bState
    lda #SHFLAG_UPDATE_CHARS
    sta.b bUpdateFlags
    rts

_get_selection_vaddr:
    ; BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (i + 1)) + 2
    rep #$20
    lda.b bSelectPos
    and #$00FF
    cmp #20
    bcs +
        ; 0-19
        cmp #10
        bcs ++
            ; 0-9
            asl
            clc
            adc #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (0 + 1)) + 2
            rts
        ++:
            ; 10-19
            sec
            sbc #10
            asl
            clc
            adc #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (1 + 1)) + 2
            rts
    +:
        ; 20-39
        cmp #30
        bcs ++
            ; 20-29
            sec
            sbc #20
            asl
            clc
            adc #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (2 + 1)) + 2
            rts
        ++:
            ; 30-39
            sec
            sbc #30
            asl
            clc
            adc #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (3 + 1)) + 2
            rts

_get_selection_char:
    phb
    .ChangeDataBank bankbyte(_char_addresses)
    rep #$30 ; 16b AXY
    lda.b bState
    and #$00FF
    asl
    tax
    lda.b bSelectPos
    and #$00FF
    clc
    adc.w loword(_char_addresses),X
    tax
    lda.w $0000,X
    sep #$20 ; 8b A
; end
    plb
    rts

_shell_push_unselect_pos:
    jsr _get_selection_vaddr
    rep #$30
    ldy.b pwDrawBuf
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    jsr _get_selection_char
    rep #$30
    and #$00FF
    ora #$0800
    ldy.b pwDrawBuf
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    rts

_shell_push_select_pos:
    jsr _get_selection_vaddr
    rep #$30
    ldy.b pwDrawBuf
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    jsr _get_selection_char
    rep #$30
    and #$00FF
    ora #$0400
    ldy.b pwDrawBuf
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    rts

_shell_update_charset:
    sep #$20 ; 8b A
    rep #$10 ; 16b XY
    lda.b bState
    cmp #STATE_UPPER
    beq @upper
    cmp #STATE_CAPS
    beq @upper
    cmp #STATE_SYMBOLS
    beq @sym
    ldx #__ShellSymLower
    bra +
@upper:
    ldx #__ShellSymUpper
    bra +
@sym:
    ldx #_ShellSymSymbols
+:
    lda #80
    sta VMAIN
    rep #$20
    ; phb
    ; .ChangeDataBank bankbyte(__ShellSymLower)
    .REPT 4 INDEX i
        lda #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (i + 1)) + 2
        sta.l VMADDR
        ldy #10
    -:
        lda.l (__ShellSymLower&$FF0000),X
        and #$00FF
        ora #$0800
        inx
        sta.l VMDATA
        lda #0
        sta.l VMDATA
        dey
        bne -
    .ENDR
    ; lda #$0036
    ; sta.l VMDATA
    ; lda #$0039
    ; sta.l VMDATA
; end
    ; plb
    rts

__ShellSymLower:
    .db "1234567890"
    .db "abcdefghij"
    .db "klmnopqrst"
    .db "uvwxyz.,?!"

__ShellSymUpper:
    .db "!@#$%^&*()"
    .db "ABCDEFGHIJ"
    .db "KLMNOPQRST"
    .db "UVWXYZ"
    .db '"'
    .db "':;"

_ShellSymSymbols:
    .db "!@#$%^&*()"
    .db ";:"
    .db '\'
    .db "/[]{}<>"
    .db "+-=_|     "
    .db ".,?!`~"
    .db '"'
    .db "':;"

_shell_pushchar:
    rep #$30
    lda.b wCharLinePos
    cmp #28
    bcc +
        phb
        .ChangeDataBank $7E
        jsl KPrintNextRow__
        plb
        stz.b wCharLinePos
    +
    ; get VRAM address
    rep #$30
    lda.l kTermPrintVMEMPtr
    and #$FFE0
    clc
    adc.b wCharLinePos
    and #$03FF
    clc
    adc #BG4_DISPTEXT_TILE_BASE_ADDR; + ROW_START*32
    ; lda.b wLenStrBuf
    ; clc
    ; adc #BG4_DISPTEXT_TILE_BASE_ADDR + ROW_START*32
    ; store VRAM address
    ldy.b pwDrawBuf
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    ; get char
    jsr _get_selection_char
    rep #$30
    and #$00FF
    ; ora #$0000
    ; store char to VRAM
    ldy.b pwDrawBuf
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    ; store char to buffer
    ldy.b pwStrBuf
    sta.b (wLenStrBuf),Y ; storing 16b which includes null terminator
    inc.b wCharLinePos
    inc.b wLenStrBuf
    rts

_shell_enter:
    rep #$20
    stz.b wLenStrBuf
    stz.b wCharLinePos
    phb
    .ChangeDataBank $7E
    jsl KPrintNextRow__
    plb
    sep #$20
    rep #$10
    lda #0
    ldy.b pwStrBuf
    sta.b (wLenStrBuf),Y
    rts

_shell_backspace:
    rts

_shell_init:
    ; disable rendering and interrupts
    sep #$20
    .DisableInt__
    lda #%10001111
    sta.l INIDISP
; first, upload graphics
    ; upload UI
    pea BG2_SHELLBACK_CHAR_BASE_ADDR
    pea 16 * 4 * 8 * 2 ; 16x4, 2bpp
    sep #$20 ; 8 bit A
    lda #bankbyte(sprites@ShellUIAsset__)
    pha
    pea loword(sprites@ShellUIAsset__)
    jsl KCopyVMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; clear text screen
    pea BG1_SHELLTEXT_TILE_BASE_ADDR
    pea 32*32*2 ; 32x32 tiles
    jsl KClearVMem
    rep #$20 ; 16b A
    pla
    pla
    ; set background screen
    pea BG2_SHELLBACK_TILE_BASE_ADDR
    pea 32*32*2 ; 32x32 tiles
    sep #$20
    lda #bankbyte(ShellBackgroundData__)
    pha
    pea loword(ShellBackgroundData__)
    jsl KCopyVMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; copy palette
    pea $6000 | bankbyte(ShellTextPalette__)
    pea loword(ShellTextPalette__)
    jsl KCopyPalette16
    sep #$20 ; 8b A
    lda #$00
    sta $04,s
    jsl KCopyPalette16
    rep #$20
    pla
    pla
    pea $2000 | bankbyte(ShellBackPalette__)
    pea loword(ShellBackPalette__)
    jsl KCopyPalette4
    rep #$20
    pla
    pla
    ; update mem registers
    sep #$20
    lda #(BG1_SHELLTEXT_TILE_BASE_ADDR >> 8) | %00
    sta.l BG1SC
    lda #(BG2_SHELLBACK_TILE_BASE_ADDR >> 8) | %00
    sta.l BG2SC
    lda #(BG4_DISPTEXT_CHAR_BASE_ADDR >> 12) | (BG2_SHELLBACK_CHAR_BASE_ADDR >> 8)
    sta.l BG12NBA
    lda #%00001011
    sta.l SCRNDESTM
    ; initialize other
    pea 256
    jsl memalloc
    stx.b pwStrBuf
    rep #$20 ; 16b A
    pla
    pea 256
    jsl memalloc
    stx.b pwDrawBuf
    rep #$20 ; 16b A
    pla
    ; set variables
    lda #0
    sta.b wLenStrBuf
    lda #0
    sta.b wLenDrawBuf
    stz.b wCharLinePos
    sep #$20 ; 8b A
    sta.b bState
    sta.b bSelectPos
    lda #SHFLAG_UPDATE_CHARS
    sta.b bUpdateFlags
    jsl _shell_push_select_pos
    ; replace renderer
    lda #bankbyte(_shell_render)
    pha
    rep #$20
    lda #loword(_shell_render)
    pha
    jsl KSetRenderer
    sep #$20
    pla
    pla
    pla
; end
    ; re-enable rendering and interrupts
    sep #$20 ; 8b A
    lda #%00001111
    sta.l INIDISP
    .RestoreInt__
    jsl kreschedule
    jsl KPrintMemoryDump__
    rts

_shell_render:
    jsl KUpdatePrinter__
    ; test flags
    sep #$20
    lda #SHFLAG_UPDATE_CHARS
    trb.b bUpdateFlags
    beq +
        jsr _shell_update_charset
    +:
    ; apply draw buf
    rep #$20
    lda.b wLenDrawBuf
    beq @skipdrawbuf
        sta.l DMA0_SIZE
        lda.b pwDrawBuf
        sta.l DMA0_SRCL
        stz.b wLenDrawBuf
        sep #$20
        phb
        pla
        sta.l DMA0_SRCH
        lda #%0000100
        sta.l DMA0_CTL
        lda #lobyte(VMADDR)
        sta.l DMA0_DEST
        lda #$01
        sta.l MDMAEN
    @skipdrawbuf:
    rtl

_shell_update:
    sep #$20
    .DisableInt__
    jsr _shell_push_unselect_pos
    rep #$20
    lda.l kJoy1Press
    bit #JOY_RIGHT
    beq +
        sep #$20
        lda.b bSelectPos
        inc A
        cmp #40
        bcc ++
            sec
            sbc #40
        ++:
        sta.b bSelectPos
    +:
    rep #$20
    lda.l kJoy1Press
    bit #JOY_LEFT
    beq +
        sep #$20
        lda.b bSelectPos
        dec A
        bpl ++
            clc
            adc #40
        ++:
        sta.b bSelectPos
    +:
    rep #$20
    lda.l kJoy1Press
    bit #JOY_DOWN
    beq +
        sep #$20
        lda.b bSelectPos
        clc
        adc #10
        cmp #40
        bcc ++
            sec
            sbc #40
        ++:
        sta.b bSelectPos
    +:
    rep #$20
    lda.l kJoy1Press
    bit #JOY_UP
    beq +
        sep #$20
        lda.b bSelectPos
        sec
        sbc #10
        bpl ++
            clc
            adc #40
        ++:
        sta.b bSelectPos
    +:
    jsr _shell_push_select_pos
    ; put char
    rep #$20
    lda.l kJoy1Press
    bit #JOY_A
    beq +
        jsr _shell_pushchar
    +:
    ; enter string
    rep #$20
    lda.l kJoy1Press
    bit #JOY_START
    beq +
        jsr _shell_enter
    +:
    ; wait for NMI and reschedule
    sep #$30
    lda #PROCESS_WAIT_NMI
    jsl ksetcurrentprocessstate
    .RestoreInt__
    jsl kreschedule
    rts

os_shell:
    jsr _shell_init
    @loop:
        jsr _shell_update
        jmp @loop

_sh_help:
    rtl

_sh_ps:
    rtl

_sh_kill:
    rtl

_sh_clear:
    rtl

_sh_echo:
    rtl

_sh_uptime:
    rtl

.ENDS