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

.DEFINE NUM_COMMANDS 0

.MACRO .DefCommand ARGS cmd
    .DSTRUCT INSTANCEOF command_t VALUES
        plLabel: .dl \1
        plName: .dl \1_name
    .ENDST
    .REDEFINE NUM_COMMANDS (NUM_COMMANDS + 1)
.ENDM

ShellCommandList:
    ; .DefCommand _sh_clear
    .DefCommand _sh_echo
    .DefCommand _sh_help
    ; .DefCommand _sh_kill
    .DefCommand _sh_meminfo
    .DefCommand _sh_ps
    .DefCommand _sh_test
    .dsl 2, $000000

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

.DEFINE CHAR_BUFFER_SIZE 28*10

; variables
.ENUM $10
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

_shell_push_current_char:
    jsr _get_selection_char
    jsr _shell_push_char
    rts

_shell_push_char:
    .ACCU 8
    pha
    rep #$30
    lda.b wLenStrBuf
    cmp #CHAR_BUFFER_SIZE
    bcc +
        rts
    +:
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
    sep #$20
    pla
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

_shell_run_command:
    .DEFINE NStrArgs $06
    .DEFINE StrBufLen $08
    .DEFINE StrBuf $0A
    .DEFINE PtrBuf $0C
    .DEFINE FoundCommandIndex $0E
    ; push pointer to command name string
    phb
    rep #$20
    lda.b (PtrBuf)
    pha
    rep #$10 ; 16b XY
    ldx #0
    ; push command name
@loop:
    sep #$20
    lda.l ShellCommandList+command_t.plName+2,X
    pha
    rep #$20
    lda.l ShellCommandList+command_t.plName,X
    pha
    ; check command match
    jsl strcmpl
    .ACCU 8
    cmp #0
    beq @runcommand
    ; command does not match, get next
    .POPN 3
    rep #$20
    txa
    clc
    adc #_sizeof_command_t
    tax
    lda.l ShellCommandList,X
    ora.l ShellCommandList+2,X
    ora.l ShellCommandList+4,X
    bne @loop
    ; bra @nocommand
@nocommand:
    ; no command found
    .POPN 2
    rep #$30
    phk
    plb
    ldy #@errtxt
    jsl kputstring
    plb
    ; free memory
    rep #$10
    ldx.b StrBuf
    jsl memfree
    rep #$10
    ldx.b PtrBuf
    jsl memfree
    rts
@runcommand:
    ; found command, run it
    .POPN 5
    plb
    rep #$30
    stx.b FoundCommandIndex
    ; push args
    lda.b PtrBuf
    pha
    lda.b NStrArgs
    pha
    pea 4
    pea 128
    rep #$10
    ldx.b FoundCommandIndex
    ; push name
    phb
    rep #$20
    lda.b StrBuf
    pha
    ; push command
    sep #$20
    lda.l ShellCommandList+2,X
    pha
    rep #$20
    lda.l ShellCommandList,X
    pha
    ; start process
    jsl kcreateprocess
    .INDEX 8
    phx
    ; change owner of memory
    sep #$30 ; 8A, 8XY
    txa
    rep #$10 ; 8A, 16XY
    ldx.b PtrBuf
    jsl memchown
    ldx.b StrBuf
    jsl memchown
    ; start process
    sep #$10 ; 8A, 8XY
    plx
    jsl kresumeprocess
    ; end
    .POPN 14
    rts
@errtxt: .db "No such command.\n\0"
@testtxt: .db "Found command!\n\0"

_shell_parse_command:
; parse line
    ; allocate string buffer
    rep #$20
    lda.b wLenStrBuf
    inc A
    pha
    jsl memalloc
    rep #$30
    stx.b StrBuf
    pla
    lda.b wLenStrBuf
    inc A
    and #$FFFE
    pha
    ; allocate pointer buffer
    jsl memalloc
    rep #$30
    stx.b PtrBuf
    pla
    lda.b PtrBuf
    pha
    lda.b StrBuf
    pha
    sta.b (PtrBuf)
    inc.b PtrBuf
    inc.b PtrBuf
    stz.b StrBufLen
    stz.b NStrArgs
    ; parse string
    ldy #0
    bra @enterspaceloop
    @insertstr:
        jsr @insert
    @spaceloop:
        ; inc.b pwStrBuf
        iny
    @enterspaceloop:
        lda.b (pwStrBuf),Y
        and #$00FF
        beq @endloop
        cmp #' '
        beq @spaceloop
        ; character is not a space
        sta.b (StrBuf)
        inc.b StrBuf
        inc.b StrBufLen
    @charloop:
        ; inc.b pwStrBuf
        iny
        lda.b (pwStrBuf),Y
        and #$00FF
        beq @endloop
        cmp #' '
        beq @insertstr ; found space: insert string, then go to space loop
        ; not a space, just insert
        sta.b (StrBuf)
        inc.b StrBuf
        inc.b StrBufLen
        bra @charloop
    @endloop:
    ; reached end of string
    lda.b StrBufLen
    beq +
        jsr @insert
    +:
    rep #$30
    plx
    stx.b StrBuf
    plx
    stx.b PtrBuf
    jsr _shell_run_command
    rts
    @insert:
        ; get new string buffer
        inc.b StrBuf
        stz.b StrBufLen
        ; add new string buffer to pointer buffer
        lda.b StrBuf
        sta.b (PtrBuf)
        inc.b PtrBuf
        inc.b PtrBuf
        ; ++nargs;
        inc.b NStrArgs
        rts
.UNDEFINE StrBuf
.UNDEFINE PtrBuf
.UNDEFINE NStrArgs
.UNDEFINE StrBufLen

_shell_push_space:
    sep #$20
    lda #' '
    jsr _shell_push_char
    rts

_shell_enter:
; next row
    phb
    .ChangeDataBank $7E
    jsl KPrintNextRow__
    plb
; parse command
    rep #$20
    lda.b wLenStrBuf
    beq @nocommand
    jsr _shell_parse_command
@nocommand:
; clear data
    rep #$20
    stz.b wLenStrBuf
    stz.b wCharLinePos
    sep #$20
    rep #$10
    lda #0
    sta.b (pwStrBuf)
    rts

_shell_backspace:
    rep #$30
    lda.b wLenStrBuf
    bne +
        rts
    +:
    ; decrement
    dec.b wCharLinePos
    dec.b wLenStrBuf
    ; put null into buffer
    sep #$20
    lda #0
    ldy.b pwStrBuf
    sta.b (wLenStrBuf),Y
    ; get VRAM address
    rep #$20
    lda.l kTermPrintVMEMPtr
    and #$FFE0
    clc
    adc.b wCharLinePos
    and #$03FF
    clc
    adc #BG4_DISPTEXT_TILE_BASE_ADDR; + ROW_START*32
    ; store VRAM address
    ldy.b pwDrawBuf
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    ; store VRAM value
    lda #0
    sta.b (wLenDrawBuf),Y
    inc.b wLenDrawBuf
    inc.b wLenDrawBuf
    ; perform backspace if wLenStrBuf > 0 and wCharLinePos == 0
    lda.b wLenStrBuf
    beq +
    lda.b wCharLinePos
    bne +
        lda #28
        sta.b wCharLinePos
        phb
        .ChangeDataBank $7E
        jsl KPrintPrevRow__
        plb
    +:
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
    pea CHAR_BUFFER_SIZE+1
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
    ; actual update code
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
    ; backspace
    rep #$20
    lda.l kJoy1Press
    bit #JOY_B
    beq +
        jsr _shell_backspace
    +:
    ; put char
    rep #$20
    lda.l kJoy1Press
    bit #JOY_A
    beq +
        jsr _shell_push_current_char
    +:
    ; put space
    rep #$20
    lda.l kJoy1Press
    bit #JOY_Y
    beq +
        jsr _shell_push_space
    +:
    ; enter string
    rep #$20
    lda.l kJoy1Press
    bit #JOY_START
    beq +
        jsr _shell_enter
    +:
    sep #$20
    .RestoreInt__
    ; wait for NMI and reschedule
    jsl pwaitfornmi
    ; lda #PROCESS_WAIT_NMI
    ; jsl ksetcurrentprocessstate
    ; jsl kreschedule
    rts

os_shell:
    jsr _shell_init
    @loop:
        jsr _shell_update
        jmp @loop
    @n: .db "shell\0"

_help_txt:
    .db "Commands:\n  \0"
_help_sep:
    .db "\n  \0"
_sh_help_name: .db "help\0"
_sh_help:
    .ChangeDataBank bankbyte(_help_txt)
    rep #$30
    ldy #loword(_help_txt)
    jsl kputstring
    rep #$30
    stz.b $06
@loop:
    ldx.b $06
    sep #$20
    lda.l ShellCommandList+command_t.plName+2,X
    pha
    plb
    rep #$20
    lda.l ShellCommandList+command_t.plName,X
    tay
    jsl kputstring
    .ChangeDataBank bankbyte(_help_sep)
    rep #$20
    ldy #loword(_help_sep)
    jsl kputstring
    rep #$30
    lda.b $06
    clc
    adc #_sizeof_command_t
    sta.b $06
    cmp #_sizeof_command_t * NUM_COMMANDS
    bcc @loop

    jsl exit

_ps_state_tbl:
    .db '?'
    .db 'R'
    .db 'S'
    .db 'I'
    .db 'W'
    .ds 255-PROCESS_WAIT_NMI-1, '?'

_ps_txt:
    .db "PI S NAME\n"
    .db "-- - ----\n\0"
_sh_ps_name: .db "ps\0"
_sh_ps:
; write header
    phb
    .ChangeDataBank bankbyte(_ps_txt)
    rep #$30
    ldy #_ps_txt
    jsl kputstring
    plb
; allocate string
    pea 255
    jsl memalloc
    rep #$30 ; 16b AXY
    pla
    cpx #0
    bne +
        jsl exit
    +:
    stx.b $08 ; $08 is mem
; iterate processes
    ldx #1
@loop:
    stx.b $06 ; $06 is current pid
    lda.l kProcTabStatus,X
    and #$00FF
    bne +
        inx
        cpx #KPROC_NUM
        bcs @end
        bra @loop
+:
    lda.b $06
    ldx.b $08
    ; write PID
    sep #$20 ; 8b A, 16b XY
    jsl writeptrb
    lda #' '
    jsl writec
    rep #$20
    ; write string
    ldy.b $08
    jsl kputstring
    ; write state
    sep #$20
    lda #0
    xba
    ldx.b $06
    lda.l kProcTabStatus,X
    tax
    lda.l _ps_state_tbl,X
    jsl kputc
    lda #' '
    jsl kputc
    rep #$20
    ; write name
    phb
    ldx.b $06
    sep #$20
    lda.l kProcTabNameBank,X
    pha
    plb
    rep #$20
    txa
    asl
    tax
    lda.l kProcTabNamePtr,X
    tay
    jsl kputstring
    plb
    sep #$20
    lda #'\n'
    jsl kputc
    rep #$30
    ; next PID
    ldx.b $06
    inx
    cpx #KPROC_NUM
    bcc @loop
@end:
    - jsl kreschedule
    jsl exit
    bra -

_sh_kill_name: .db "kill\0"
_sh_kill:
    jsl exit

_sh_clear_name: .db "clear\0"
_sh_clear:
    jsl exit

_sh_echo_name: .db "echo\0"
_sh_echo:
    rep #$30 ; 16b AXY
    ; $01,s: int argc
    ; $03,s: char **argv
    lda $03,s
    inc A
    inc A
    tax
    lda $01,s
    beq @end
    dec A
    beq @end
@loop:
    ldy.w $0000,X
    pha
    phx
    php
    jsl kputstring
    sep #$20
    lda #' '
    jsl kputc
    plp
    plx
    pla
    inx
    inx
    dec A
    bne @loop
@end:
    sep #$20
    lda #'\n'
    jsl kputc
    jsl exit

_sh_meminfo_name: .db "meminfo\0"
_sh_meminfo:
    jsl KPrintMemoryDump__
    jsl exit

_sh_test_name: .db "test\0"
_sh_test:
    jml KTestProgram__

; _sh_uptime_name: .db "uptime\0"
; _sh_uptime:
;     rtl

.ENDS