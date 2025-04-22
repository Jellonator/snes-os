.include "base.inc"

.BANK $02 SLOT "ROM"
.SECTION "ShellAssets" FREE

.DEFINE BG1_CHAR_BASE_ADDR $1000
.DEFINE BG2_CHAR_BASE_ADDR $0000
.DEFINE OBJ1_CHAR_BASE_ADDR $0000
.DEFINE OBJ2_CHAR_BASE_ADDR $1000
.DEFINE BG1_TILE_BASE_ADDR $0800
.DEFINE BG2_TILE_BASE_ADDR $0C00

.DEFINE MIN_COORD_Y 24
.DEFINE MAX_COORD_Y 200-1
.DEFINE MIN_COORD_X 24
.DEFINE MAX_COORD_X 232-1

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
    .IF iy == 23
        .dsw 3, deft($20, 2)
        .dw deft($0A, 0), deft($0C, 0)
        .dsw 24, deft($0E, 0)
        .dsw 3, deft($20, 2)
    .ELIF iy == 24
        .dsw 3, deft($20, 2)
        .dw deft($2A, 0), deft($2C, 0)
        .dsw 24, deft($2E, 0)
        .dsw 3, deft($20, 2)
    .ELSE
        .REPT 32 INDEX ix
            .IF ix < 3 || ix >= 32-3 || iy < 3 || iy >= 32-8
                .dw deft($20, 2)
            .ELSE
                .dw deft($00, 2)
            .ENDIF
        .ENDR
    .ENDIF
.ENDR

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
    lda #(BG1_TILE_BASE_ADDR >> 8) | %00
    sta.l BG1SC
    lda #(BG2_TILE_BASE_ADDR >> 8) | %00
    sta.l BG2SC
    lda #(BG1_CHAR_BASE_ADDR >> 12) | (BG2_CHAR_BASE_ADDR >> 8)
    sta.l BG12NBA
    lda #%00000000 | (OBJ1_CHAR_BASE_ADDR >> 13) | ((OBJ2_CHAR_BASE_ADDR - OBJ1_CHAR_BASE_ADDR - $1000) >> 9)
    sta.l OBSEL
; set bgmode and window values
    lda #%00010011
    sta.l SCRNDESTM
    lda #%00010010
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
; upload default tile data
    pea BG2_TILE_BASE_ADDR
    pea $0400*2
    .PEAL _default_bg2_tiles
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
    rts

_desktop_render:
    ; upload one singular sprite (mouse cursor)
    ; rep #$20
    ; lda #0
    ; sta.l OAMADDR
    ; sep #$20
    ; .REPT 4 INDEX i
    ;     lda.l kSpriteTable+i
    ;     sta.l OAMDATA
    ; .ENDR
    ; rep #$20
    ; lda #512
    ; sta.l OAMADDR
    ; lda.l kSpriteTableHigh
    ; sta.l OAMDATA
    jsl vUploadSpriteData__
    rtl

_desktop_update:
    rep #$30
    ; controller movement
    lda.l kJoy1Held
    bit #JOY_UP
    beq +
        sep #$20
        lda.b bMouseY
        dec A
        .AMAXU P_IMM MIN_COORD_Y
        sta.b bMouseY
        rep #$20
        lda.l kJoy1Held
    +:
    bit #JOY_DOWN
    beq +
        sep #$20
        lda.b bMouseY
        inc A
        .AMINU P_IMM MAX_COORD_Y
        sta.b bMouseY
        rep #$20
        lda.l kJoy1Held
    +:
    bit #JOY_LEFT
    beq +
        sep #$20
        lda.b bMouseX
        dec A
        .AMAXU P_IMM MIN_COORD_X
        sta.b bMouseX
        rep #$20
        lda.l kJoy1Held
    +:
    bit #JOY_RIGHT
    beq +
        sep #$20
        lda.b bMouseX
        inc A
        .AMINU P_IMM MAX_COORD_X
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
        .AMINU P_IMM MAX_COORD_X*256
        sta.b bMouseXLow
        jmp @end_x
    @neg_x:
        and #$7F
        .MultiplyStatic MOUSE_MOVE_MULT
        sta.b $00
        lda.b bMouseXLow
        sec
        sbc.b $00
        .AMAXU P_IMM MIN_COORD_X*256
        sta.b bMouseXLow
    @end_x:
    lda.l kMouse1Y
    bit #$80
    bne @neg_y
        and #$7F
        .MultiplyStatic MOUSE_MOVE_MULT
        clc
        adc.b bMouseYLow
        .AMINU P_IMM MAX_COORD_Y*256
        sta.b bMouseYLow
        jmp @end_y
    @neg_y:
        and #$7F
        .MultiplyStatic MOUSE_MOVE_MULT
        sta.b $00
        lda.b bMouseYLow
        sec
        sbc.b $00
        .AMAXU P_IMM MIN_COORD_Y*256
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
    ; end
    jsl procWaitNMI
    rts

.ENDS
