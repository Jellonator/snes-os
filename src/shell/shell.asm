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
    .DCOLOR_RGB5 22, 22, 22
    .DCOLOR_RGB5 12, 12, 12
; unselected color
    .DCOLOR_RGB5  0,  0,  0
    .DCOLOR_RGB5 12, 12, 12
    .DCOLOR_RGB5  9,  9,  9
    .DCOLOR_RGB5  7,  7,  7

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
    .DefCommand shCat
    .DefCommand shCp
    .DefCommand os_desktop
    .DefCommand shEcho
    .DefCommand _sh_help
    ; .DefCommand _sh_kill
    .DefCommand _sh_meminfo
    .DefCommand shMkdir
    .DefCommand shPs
    .DefCommand shRm
    .DefCommand shTest
    .DefCommand shTestProdcons
    .DefCommand shTouch
    .dsl 2, $000000

; tile data addresses; granularity is (X % $0400) words
.DEFINE BG1_SHELLTEXT_TILE_BASE_ADDR $0400
.DEFINE BG2_SHELLBACK_TILE_BASE_ADDR $0800
.DEFINE BG4_DISPTEXT_TILE_BASE_ADDR $0000
; tile character addresses; granularity is (X % $1000) words
.DEFINE BG2_SHELLBACK_CHAR_BASE_ADDR $2000
.DEFINE BG4_DISPTEXT_CHAR_BASE_ADDR $1000
; BG4 refers to data from kprint.asm
; object data address
.DEFINE OBJ1_ICON_BASE_ADDR $4000
.DEFINE OBJ2_ICON_BASE_ADDR $5000

.DEFINE DEADZONE_LEFT 2 ; screen offset from left
.DEFINE MAX_LINE_WIDTH 28 ; maximum of 28 characters per row
.DEFINE ROW_START 25 ; row to start writing to

.ENUMID 0
.ENUMID STATE_HIDDEN
.ENUMID STATE_LOWER
.ENUMID STATE_UPPER
.ENUMID STATE_CAPS
.ENUMID STATE_SYMBOLS
.ENUMID STATE_END

_char_addresses:
    .dw __ShellSymLower
    .dw __ShellSymLower
    .dw __ShellSymUpper
    .dw __ShellSymUpper
    .dw _ShellSymSymbols

_state_next:
    .db STATE_UPPER
    .db STATE_UPPER
    .db STATE_SYMBOLS
    .db STATE_SYMBOLS
    .db STATE_LOWER

.DEFINE SHFLAG_UPDATE_CHARS $80

.DEFINE CHAR_BUFFER_SIZE 28*10

.DEFINE KEYBOARD_INPUT_COLUMNS 10

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
    ; timer
    bTimer db
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

_get_selection_position:
    ; BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (i + 1)) + 2
    sep #$20
    lda.b bSelectPos
    cmp #20
    bcs +
        ; 0-19
        cmp #KEYBOARD_INPUT_COLUMNS
        bcs ++
            ; 0-9
            xba
            lda #0
            xba
            rts
        ++:
            ; 10-19
            xba
            lda #1
            xba
            sec
            sbc #KEYBOARD_INPUT_COLUMNS
            rts
    +:
        ; 20-39
        cmp #3*KEYBOARD_INPUT_COLUMNS
        bcs ++
            ; 20-29
            xba
            lda #2
            xba
            sec
            sbc #2*KEYBOARD_INPUT_COLUMNS
            rts
        ++:
            ; 30-39
            xba
            lda #3
            xba
            sec
            sbc #3*KEYBOARD_INPUT_COLUMNS
            rts

_get_selection_vaddr:
    ; BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (i + 1)) + 2
    rep #$20
    lda.b bSelectPos
    and #$00FF
    cmp #20
    bcs +
        ; 0-19
        cmp #KEYBOARD_INPUT_COLUMNS
        bcs ++
            ; 0-9
            asl
            clc
            adc #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (0 + 1)) + 2
            rts
        ++:
            ; 10-19
            sec
            sbc #KEYBOARD_INPUT_COLUMNS
            asl
            clc
            adc #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (1 + 1)) + 2
            rts
    +:
        ; 20-39
        cmp #3*KEYBOARD_INPUT_COLUMNS
        bcs ++
            ; 20-29
            sec
            sbc #2*KEYBOARD_INPUT_COLUMNS
            asl
            clc
            adc #BG1_SHELLTEXT_TILE_BASE_ADDR + (64 * (2 + 1)) + 2
            rts
        ++:
            ; 30-39
            sec
            sbc #3*KEYBOARD_INPUT_COLUMNS
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
        ldy #KEYBOARD_INPUT_COLUMNS
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
    stz.b bTimer
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
        jsl vPrintNextRow
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
    jsl stringCmpL
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
    jsl kPutString
    plb
    ; free memory
    rep #$10
    ldx.b StrBuf
    jsl memFree
    rep #$10
    ldx.b PtrBuf
    jsl memFree
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
    jsl procCreate
    .INDEX 8
    phx
    ; change owner of memory
    sep #$30 ; 8A, 8XY
    txa
    rep #$10 ; 8A, 16XY
    ldx.b PtrBuf
    jsl memChangeOwner
    ldx.b StrBuf
    jsl memChangeOwner
    ; start process
    sep #$10 ; 8A, 8XY
    plx
    jsl procResume
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
    jsl memAlloc
    rep #$30
    stx.b StrBuf
    pla
    lda.b wLenStrBuf
    inc A
    and #$FFFE
    pha
    ; allocate pointer buffer
    jsl memAlloc
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
    ; if at least one char in buffer, then increment arg count
    lda.b StrBufLen
    beq +
        inc.b NStrArgs
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
    stz.b bTimer
; next row
    phb
    .ChangeDataBank $7E
    jsl vPrintNextRow
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
    stz.b bTimer
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
        jsl vPrintPrevRow
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
    jsl vCopyMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; clear text screen
    pea BG1_SHELLTEXT_TILE_BASE_ADDR
    pea 32*32*2 ; 32x32 tiles
    jsl vClearMem
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
    jsl vCopyMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; set sprites
    pea OBJ1_ICON_BASE_ADDR
    pea 16 * 4 * 8 * 4 ; 16x4, 4bpp
    sep #$20
    lda #bankbyte(sprites@ShellUISprites__)
    pha
    pea loword(sprites@ShellUISprites__)
    jsl vCopyMem
    sep #$20 ; 8 bit A
    pla
    rep #$20 ; 16 bit A
    pla
    pla
    pla
    ; copy palette
    pea $6000 | bankbyte(ShellTextPalette__)
    pea loword(ShellTextPalette__)
    jsl vCopyPalette16
    sep #$20 ; 8b A
    lda #$00
    sta $04,s
    jsl vCopyPalette16
    rep #$20
    pla
    pla
    pea $2000 | bankbyte(ShellBackPalette__)
    pea loword(ShellBackPalette__)
    jsl vCopyPalette4
    rep #$20
    pla
    pla
    pea $8000 | bankbyte(ShellTextPalette__)
    pea loword(ShellTextPalette__)
    jsl vCopyPalette16
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
    lda #%00011011
    sta.l SCRNDESTM
    lda #%00000000 | (OBJ1_ICON_BASE_ADDR >> 13) | ((OBJ2_ICON_BASE_ADDR - OBJ1_ICON_BASE_ADDR - $1000) >> 9)
    sta.l OBSEL
    ; initialize other
    pea CHAR_BUFFER_SIZE+1
    jsl memAlloc
    stx.b pwStrBuf
    rep #$20 ; 16b A
    pla
    pea 256
    jsl memAlloc
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
    jsl vSetRenderer
    sep #$20
    pla
    pla
    pla
; upload sprites
    jsl vClearSpriteData__
    jsl vUploadSpriteData__
; end
    ; re-enable rendering and interrupts
    sep #$20 ; 8b A
    lda #%00001111
    sta.l INIDISP
    .RestoreInt__
    rts

_shell_render:
    jsl vUpdatePrinter
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
    ; test flags
    sep #$20
    lda #SHFLAG_UPDATE_CHARS
    trb.b bUpdateFlags
    beq +
        jsr _shell_update_charset
    +:
    ; upload sprites
    jsl vUploadSpriteData__
    rtl

_shell_update:
    sep #$20
    .DisableInt__
    ; check if we have renderer
    lda.l kRendererProcess
    beq @fix_renderer
    cmp.l kCurrentPID
    beq @update
        ; we do not have renderer
        .RestoreInt__
        ; wait for NMI and reschedule
        jsl procWaitNMI
        rts
    @fix_renderer:
        ; renderer is null, re-initialize
        rep #$20
        pla
        jmp os_shell
@update:
    ; actual update code
    jsr _shell_push_unselect_pos
    rep #$20
    lda.l kJoy1Press
    bit #JOY_RIGHT
    beq +
        sep #$20
        lda.b bSelectPos
        cmp #1*KEYBOARD_INPUT_COLUMNS-1
        beq @wrap_right
        cmp #2*KEYBOARD_INPUT_COLUMNS-1
        beq @wrap_right
        cmp #3*KEYBOARD_INPUT_COLUMNS-1
        beq @wrap_right
        cmp #4*KEYBOARD_INPUT_COLUMNS-1
        beq @wrap_right
        inc A
        cmp #40
        bcc ++
            sec
            sbc #40
        ++:
        sta.b bSelectPos
        jmp +
        @wrap_right:
            sec
            sbc #9
            sta.b bSelectPos
    +:
    rep #$20
    lda.l kJoy1Press
    bit #JOY_LEFT
    beq +
        sep #$20
        lda.b bSelectPos
        cmp #0*KEYBOARD_INPUT_COLUMNS
        beq @wrap_left
        cmp #1*KEYBOARD_INPUT_COLUMNS
        beq @wrap_left
        cmp #2*KEYBOARD_INPUT_COLUMNS
        beq @wrap_left
        cmp #3*KEYBOARD_INPUT_COLUMNS
        beq @wrap_left
        dec A
        bpl ++
            clc
            adc #40
        ++:
        sta.b bSelectPos
        jmp +
        @wrap_left:
            clc
            adc #9
            sta.b bSelectPos
    +:
    rep #$20
    lda.l kJoy1Press
    bit #JOY_DOWN
    beq +
        sep #$20
        lda.b bSelectPos
        clc
        adc #KEYBOARD_INPUT_COLUMNS
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
        sbc #KEYBOARD_INPUT_COLUMNS
        bpl ++
            clc
            adc #40
        ++:
        sta.b bSelectPos
    +:
    rep #$20
    lda.l kJoy1Press
    bit #JOY_SELECT
    beq +
        sep #$30
        ldx.b bState
        lda.l _state_next,X
        sta.b bState
        lda #SHFLAG_UPDATE_CHARS
        tsb.b bUpdateFlags
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
    ; set typing indicator
    inc.b bTimer
    lda #25*8 - 1
    sta.l kSpriteTable.1.pos_y
    lda.b bTimer
    bit #%00100000
    beq +
        lda #$F0
        sta.l kSpriteTable.1.pos_y
    +:
    lda.b wCharLinePos
    inc A
    inc A
    asl
    asl
    asl
    sta.l kSpriteTable.1.pos_x
    lda #$04
    sta.l kSpriteTable.1.tile
    lda #%00110000
    sta.l kSpriteTable.1.flags
    ; set selection indicator
    jsr _get_selection_position
    sep #$20
    inc A
    asl
    asl
    asl
    asl
    dec A
    sta.l kSpriteTable.2.pos_x
    xba
    inc A
    asl
    asl
    asl
    asl
    dec A
    sta.l kSpriteTable.2.pos_y
    lda #$24
    sta.l kSpriteTable.2.tile
    lda #%00110000
    sta.l kSpriteTable.2.flags
    lda #%00001000
    sta.l kSpriteTableHigh+0
    .RestoreInt__
    ; wait for NMI and reschedule
    jsl procWaitNMI
    rts

_snow_logo:
    .db "/--------------------------" "\\"
    .db "|                          |"
    .db "| /--- /\  | \| |/ |   |   |"
    .db "| |    | \ |  \ /  |   |   |"
    .db "| \--\ | | | >-*-< |   |   |"
    .db "|    | | \ |  / \  | ^ |   |"
    .db "| ---/ |  \/ /| |\ \/ \/OS |"
    .db "|                          |"
    .db "\--------------------------/"
    .db "type 'help' for command list"
    .db "or, type 'help <command>'\n"
    .db "for information about that\n"
    .db "command.\n\0"

os_shell:
    jsr _shell_init
    phb
    .ChangeDataBank bankbyte(_snow_logo)
    rep #$10
    ldy #loword(_snow_logo)
    jsl kPutString
    plb
    @loop:
        jsr _shell_update
        jmp @loop
    @n: .db "shell\0"

_help_txt:
    .db "Commands:\n  \0"
_help_break:
    .db "\n  \0"
_help_err_too_many_args:
    .db "Expected at most one\nparameter.\n\0"
_sh_help_name: .db "help\0"
    ; $01,s: int argc
    ; $03,s: char **argv
_sh_help:
    ; check if there are arguments
    rep #$30
    lda $01,S
    cmp #3
    bcc +
        phb
        phk
        plb
        ldy #_help_err_too_many_args
        jsl kPutString
        plb
        jsl procExit
    +:
    cmp #2
    bcc +
        jmp _sh_help_command
    +:
    ; default behavior:
    .ChangeDataBank bankbyte(_help_txt)
    rep #$30
    ldy #loword(_help_txt)
    jsl kPutString
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
    jsl kPutString
    .ChangeDataBank bankbyte(_help_break)
    rep #$20
    ldy #loword(_help_break)
    jsl kPutString
    rep #$30
    lda.b $06
    clc
    adc #_sizeof_command_t
    sta.b $06
    cmp #_sizeof_command_t * NUM_COMMANDS
    bcc @loop
    jsl procExit
_help_base_path:
    .db "/static/help/\0"
_help_err_no_file:
    .db "No help exists for command.\n\0"
    ; $01,s: int argc
    ; $03,s: char **argv
_sh_help_command:
    ; allocate buffer
    pea 64
    jsl memAlloc
    rep #$30
    pla
    stx.b $08
    sep #$20
    lda #$7F
    sta.b $0A
    sta.b $0E
    ; write base path
    ldy #0
    ldx #0
    @loop_copy_base:
        lda.l _help_base_path,X
        beq @end_copy_base
        sta [$08],Y
        inx
        iny
        jmp @loop_copy_base
@end_copy_base:
    ; write command name
    rep #$30
    lda $03,S
    inc A
    inc A
    tax
    lda.w $0000,X
    sta.b $0C
    ldx #FS_MAX_FILENAME_LEN
    sep #$20
    @loop_copy_name:
        lda [$0C]
        beq @end_copy_name
        sta [$08],Y
        iny
        inc.b $0C
        dex
        bmi @no_such_help
        jmp @loop_copy_name
@end_copy_name:
    lda #0
    sta [$08],Y
    ; open file
    rep #$30
    ldx.b $08
    jsl fsOpen
    rep #$30
    cpx #0
    bne +
@no_such_help:
        phb
        phk
        plb
        ldy #_help_err_no_file
        jsl kPutString
        plb
        jsl procExit
    +:
    stx.b $10
    ; loop read and print
    sep #$20
    lda #$7F
    pha
    rep #$20
    lda.b $08
    pha
    pea 60
    @loop:
        rep #$30
        lda.b $08
        sta $03,S
        ldx.b $10
        jsl fsRead
        rep #$30
        cmp #0
        beq @end_loop
        ; got text
        ; put null terminator
        tay
        lda #0
        sep #$20
        sta [$08],Y
        ldy.b $08
        jsl kPutString
        jmp @loop
    @end_loop:
    .POPN 5
    ; close file
    rep #$30
    ldx.b $10
    jsl fsClose
@end:
    jsl procExit

_sh_kill_name: .db "kill\0"
_sh_kill:
    jsl procExit

_sh_clear_name: .db "clear\0"
_sh_clear:
    jsl procExit

_sh_meminfo_name: .db "meminfo\0"
_sh_meminfo:
    jsl memPrintDump
    jsl procExit

; _sh_uptime_name: .db "uptime\0"
; _sh_uptime:
;     rtl

.ENDS