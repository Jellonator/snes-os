.include "base.inc"

.BANK $02 SLOT "ROM"
.SECTION "Desktop" FREE

.DEFINE MOUSE_MOVE_MULT 128

os_desktop_name:
    .db "desktop\0"
os_desktop:
    jsr _desktop_init
@loop:
    jsr _desktop_update
    jmp @loop

_default_bg2_tiles:
.REPT 32 INDEX iy
    .IF iy == DESKTOP_TILE_MAX_Y - 1
        .dsw 3, deft($20, 2)
        .dw deft($0A, 0), deft($0C, 0)
        .dsw 24, deft($0E, 0)
        .dsw 3, deft($20, 2)
    .ELIF iy == DESKTOP_TILE_MAX_Y
        .dsw 3, deft($20, 2)
        .dw deft($2A, 0), deft($2C, 0)
        .dsw 24, deft($2E, 0)
        .dsw 3, deft($20, 2)
    .ELSE
        .REPT 32 INDEX ix
            .IF ix < DESKTOP_TILE_MIN_X || ix > DESKTOP_TILE_MAX_X || iy < DESKTOP_TILE_MIN_Y || iy > DESKTOP_TILE_MAX_Y
                .dw deft($20, 2)
            .ELSE
                .dw deft($00, 2)
            .ENDIF
        .ENDR
    .ENDIF
.ENDR

_hdma_BG12NBA_table:
    .db (8+WINDOW_CONTENT_MINIMUM_Y)*8
    .db ((DESKTOP_BG1_CHAR_BASE_ADDR + $0000) >> 12) | (DESKTOP_BG2_CHAR_BASE_ADDR >> 8)
    .db 64
    .db ((DESKTOP_BG1_CHAR_BASE_ADDR + $3000) >> 12) | (DESKTOP_BG2_CHAR_BASE_ADDR >> 8)
    .db 64
    .db ((DESKTOP_BG1_CHAR_BASE_ADDR + $6000) >> 12) | (DESKTOP_BG2_CHAR_BASE_ADDR >> 8)
    .db $00

; NOTE: INDEX loops at $300. We can only index up to $3FF, which is not
; sufficient to fill the entire screen of tiles. So instead, we loop at a set
; point, and use HDMA to swap BG12NBA
.DEFINE INDEX $0300
_default_bg1_tiles:
.REPT 32 INDEX iy
    ; shift tile IDs up at key Y locations
    .IF ((iy+8-WINDOW_CONTENT_MINIMUM_Y)#8) == 0
        .IF (INDEX#$10) == $0E
            .REDEFINE INDEX (INDEX - $0300)
        .ELSE
            .REDEFINE INDEX (INDEX - $0300)
        .ENDIF
    .ENDIF
    .REPT 32 INDEX ix
        .IF ix < WINDOW_CONTENT_MINIMUM_X || ix > WINDOW_CONTENT_MAXIMUM_X || iy < WINDOW_CONTENT_MINIMUM_Y || iy > WINDOW_CONTENT_MAXIMUM_Y
            .dw 0
        .ELSE
            ; skip 'null' tiles (key tiles we keep blank, at the start of each $3000 word block)
            ; we keep these tiles null as we can not use windowing– the main
            ; sub screens must both be visible at all screen locations for
            ; hi-res to function. So, we keep a couple empty tiles to place
            ; at the edges of the screen.
            .IF (INDEX #$0300) == 0
                .REDEFINE INDEX (INDEX + $02)
            .ENDIF
            .dw deft(INDEX, 1)
            .IF (INDEX#$10) == $0E
                .REDEFINE INDEX (INDEX + $12)
            .ELSE
                .REDEFINE INDEX (INDEX + $02)
            .ENDIF
        .ENDIF
    .ENDR
.ENDR
.UNDEFINE INDEX

.ENUM $10
    bMouseXLow db
    bMouseX db
    bMouseYLow db
    bMouseY db
.ENDE

_desktop_init:
    ; disable rendering and interrupts
    sep #$20
    .DisableInt__
    lda #%10001111
    sta.l INIDISP
    jsl windowInit__
; set renderer
    .PEAL _desktop_render
    jsl vSetRenderer
    .POPN 3
; clear vmem
    pea $0000
    pea $0000
    jsl vClearMem
    .POPN 4
; set memory locations
    sep #$20
    lda #(DESKTOP_BG1_TILE_BASE_ADDR >> 8) | %00
    sta.l BG1SC
    lda #(DESKTOP_BG2_TILE_BASE_ADDR >> 8) | %00
    sta.l BG2SC
    lda #(DESKTOP_BG1_CHAR_BASE_ADDR >> 12) | (DESKTOP_BG2_CHAR_BASE_ADDR >> 8)
    sta.l BG12NBA
    lda #%00000000 | (DESKTOP_OBJ1_CHAR_BASE_ADDR >> 13) | ((DESKTOP_OBJ2_CHAR_BASE_ADDR - DESKTOP_OBJ1_CHAR_BASE_ADDR - $1000) >> 9)
    sta.l OBSEL
; set bgmode and window values
    lda #%00010011
    sta.l SCRNDESTM
    lda #%00010011
    sta.l SCRNDESTS
    lda #%00110000 | 5
    sta.l BGMODE
    sep #$20
    lda #0
    sta.l BG1HOFS
    sta.l BG1HOFS
    sta.l BG2HOFS
    sta.l BG2HOFS
    rep #$20
    lda #$FFFE
    sep #$20
    sta.l BG1VOFS
    xba
    sta.l BG1VOFS
    xba
    sta.l BG2VOFS
    xba
    sta.l BG2VOFS
    lda #%00000001
    sta.l SETINI
; upload palettes
    pea $0000 | bankbyte(palettes@desktop_base)
    pea loword(palettes@desktop_base)
    jsl vCopyPalette4
    .POPN 4
    pea $0400 | bankbyte(palettes@desktop_close)
    pea loword(palettes@desktop_close)
    jsl vCopyPalette4
    .POPN 4
    pea $0800 | bankbyte(palettes@desktop_blackout)
    pea loword(palettes@desktop_blackout)
    jsl vCopyPalette4
    .POPN 4
    pea $8000 | bankbyte(palettes@desktop_sprite_mouse)
    pea loword(palettes@desktop_sprite_mouse)
    jsl vCopyPalette16
    .POPN 4
    pea $1000 | bankbyte(palettes@grayscale)
    pea loword(palettes@grayscale)
    jsl vCopyPalette16
    .POPN 4
; upload default tile data
    pea DESKTOP_BG2_TILE_BASE_ADDR
    pea $0400*2
    .PEAL _default_bg2_tiles
    jsl vCopyMem
    .POPN 7
    pea DESKTOP_BG1_TILE_BASE_ADDR
    pea $0400*2
    .PEAL _default_bg1_tiles
    jsl vCopyMem
    .POPN 7
; upload desktop character data
    pea $0000
    pea $0400
    .PEAL sprites@DesktopUI__
    jsl vCopyMem
    .POPN 7
    pea $0400
    pea $0400
    .PEAL sprites@DesktopSprites__
    jsl vCopyMem
    .POPN 7
; clear sprite data
    jsl vClearSpriteData__
    jsl vUploadSpriteData__
; set initial values
    rep #$30
    lda #128
    sta.b bMouseX
    sta.b bMouseY
; re-enable render
    sep #$20 ; 8b A
    lda #%00001111
    sta.l INIDISP
    .RestoreInt__
; make one single window
    .PEAL _defaultwindow
    jsl windowCreate
    .POPN 3
    .PEAL _defaultwindow2
    jsl windowCreate
    .POPN 3
    rts

.DSTRUCT _defaultwindow INSTANCEOF desktop_window_create_params_t VALUES
    width .db 12
    height .db 12
    pos_x .db 0
    pos_y .db 0
    renderTile .dl _tilerender_null
.ENDST

.DSTRUCT _defaultwindow2 INSTANCEOF desktop_window_create_params_t VALUES
    width .db 8
    height .db 8
    pos_x .db 30
    pos_y .db 30
    renderTile .dl _tilerender_null
.ENDST

; renderTile([x16]WID window, [By16]void* buffer, [s8]int x, [s8] int y)
; buffer[  0.. 32] is first tile,
; buffer[ 32.. 64] is second tile
; buffer[ 64.. 96] is third tile
; buffer[ 96..128] is fourth tile.
; Each tile has four bitplanes: 0101010101010101,2323232323232323
_tilerender_null:
    .ACCU 16
    .INDEX 16
    ; set whole tile to white
    lda #$FFFF
    ldx #128/2
    @loop:
        sta.w $0000,Y
        iny
        iny
        dex
        bne @loop
    rtl

_desktop_render:
    ; set up HDMA
    rep #$20
    lda #%00000000 + ($0100*lobyte(BG12NBA))
    sta.l DMA1_CTL
    lda #loword(_hdma_BG12NBA_table)
    sta.l DMA1_SRCL
    sep #$20
    lda #bankbyte(_hdma_BG12NBA_table)
    sta.l DMA1_SRCH
    lda #$02
    sta.l HDMAEN
    ; upload data
    jsl vUploadSpriteData__
    jsl windowRender__
    rtl

_desktop_update:
    sep #$20
    .DisableInt__
    rep #$30
    ; controller movement
    lda.l kJoy1Held
    bit #JOY_UP
    beq +
        sep #$20
        lda.b bMouseY
        dec A
        .AMAXU P_IMM MIN_MOUSE_COORD_Y
        sta.b bMouseY
        rep #$20
        lda.l kJoy1Held
    +:
    bit #JOY_DOWN
    beq +
        sep #$20
        lda.b bMouseY
        inc A
        .AMINU P_IMM MAX_MOUSE_COORD_Y
        sta.b bMouseY
        rep #$20
        lda.l kJoy1Held
    +:
    bit #JOY_LEFT
    beq +
        sep #$20
        lda.b bMouseX
        dec A
        .AMAXU P_IMM MIN_MOUSE_COORD_X
        sta.b bMouseX
        rep #$20
        lda.l kJoy1Held
    +:
    bit #JOY_RIGHT
    beq +
        sep #$20
        lda.b bMouseX
        inc A
        .AMINU P_IMM MAX_MOUSE_COORD_X
        sta.b bMouseX
        rep #$20
        lda.l kJoy1Held
    +:
    ; mouse movement
    rep #$20
    lda.l kMouse1X
    bit #$80
    bne @neg_x
        and #$007F
        .MultiplyStatic MOUSE_MOVE_MULT
        clc
        adc.b bMouseXLow
        .AMINU P_IMM MAX_MOUSE_COORD_X*256
        sta.b bMouseXLow
        jmp @end_x
    @neg_x:
        and #$7F
        .MultiplyStatic MOUSE_MOVE_MULT
        sta.b $00
        lda.b bMouseXLow
        sec
        sbc.b $00
        .AMAXU P_IMM MIN_MOUSE_COORD_X*256
        sta.b bMouseXLow
    @end_x:
    lda.l kMouse1Y
    bit #$80
    bne @neg_y
        and #$7F
        .MultiplyStatic MOUSE_MOVE_MULT
        clc
        adc.b bMouseYLow
        .AMINU P_IMM MAX_MOUSE_COORD_Y*256
        sta.b bMouseYLow
        jmp @end_y
    @neg_y:
        and #$7F
        .MultiplyStatic MOUSE_MOVE_MULT
        sta.b $00
        lda.b bMouseYLow
        sec
        sbc.b $00
        .AMAXU P_IMM MIN_MOUSE_COORD_Y*256
        sta.b bMouseYLow
    @end_y:
    ; set sprite location
    sep #$20
    lda.b bMouseX
    sta.l kSpriteTable.1.pos_x
    lda.b bMouseY
    sta.l kSpriteTable.1.pos_y
    lda #$40
    sta.l kSpriteTable.1.tile
    lda #%00110000
    sta.l kSpriteTable.1.flags
    lda #%00000010
    sta.l kSpriteTableHigh+0
    ; update windows
    jsl windowUpdate__
    ; end
    sep #$20
    .RestoreInt__
    jsl procWaitNMI
    rts

.ENDS
