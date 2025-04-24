.include "base.inc"

.BANK $02 SLOT "ROM"
.SECTION "Windowing" FREE

_target_address_for_tile:
.REPT 32 INDEX iy
    .REPT 32 INDEX ix
        .IF ix < 4 || ix >= 24 || iy < 3 || iy >= 23
            .dw 0
        .ELSE
            .dw (ix*2 + iy*2*24) * 16
        .ENDIF
    .ENDR
.ENDR

windowInit__:
    phb
    .ChangeDataBank $7E
; clear tile table
    rep #$10
    sep #$20
    ldy #32*32-1
    lda #0
@loop_clear_tiles:
        sta.w kWindowTileTabOwner,Y
        sta.w kWindowTileTabDirty,Y
        sta.w kWindowDirtyTileList,Y
        dey
        bpl @loop_clear_tiles
; clear windows
    ldy #MAX_WINDOW_COUNT
@loop_clear_windows:
        sta.w kWindowTabProcess,Y
        sta.w kWindowTabPosX,Y
        sta.w kWindowTabPosY,Y
        sta.w kWindowTabWidth,Y
        sta.w kWindowTabHeight,Y
        sta.w kWindowOrder,Y
        dey
        bpl @loop_clear_windows
; clear buffer and sizes
    rep #$20
    lda #0
    sta.w kWindowDrawBufferSize
    sta.w kWindowTileBufferSize
    sta.w kWindowNumDirtyTiles
    sta.w kWindowNumWindows
; end
    plb
    rtl

; [x8]WID windowCreate([s24]desktop_window_create_params_t* params)
; params: $04,S
windowCreate:
    .DEFINE CURRENT_WINDOW_ID $00
    .DEFINE PARAMS $01
    .DEFINE MAX_X $04
    .DEFINE MAX_Y $05
    sep #$20
    .DisableInt__ ; [+1, 1]
; Check that there are free windows
    rep #$30
    lda.l kWindowNumWindows
    cmp #MAX_WINDOW_COUNT
    bcc @sufficient_windows
        sep #$30
        .RestoreInt__
        ldx #0
        rtl
@sufficient_windows:
    tax
    inc A
    sta.l kWindowNumWindows
; bump up each window ID (new window will take window order 0)
    sep #$30
    sta.b CURRENT_WINDOW_ID
    cpx #0
    beq @end_bump_windows
@loop_bump_windows:
        lda.l kWindowOrder-1,X
        sta.l kWindowOrder,X
        dex
        bne @loop_bump_windows
@end_bump_windows:
; put current window into order
    lda.b CURRENT_WINDOW_ID
    sta.l kWindowOrder
; copy PID into window
    ldx.b CURRENT_WINDOW_ID
    lda.l kCurrentPID
    sta.l kWindowTabProcess,X
; set up params
    lda 1+$04,S
    sta.b PARAMS+0
    lda 1+$05,S
    sta.b PARAMS+1
    lda 1+$06,S
    sta.b PARAMS+2
; Copy render function into window
    ldy #desktop_window_create_params_t.renderTile
    lda [PARAMS],Y
    sta.l kWindowTabRenderFuncLow,X
    iny
    lda [PARAMS],Y
    sta.l kWindowTabRenderFuncPage,X
    iny
    lda [PARAMS],Y
    sta.l kWindowTabRenderFuncBank,X
; Determine window location
    ldy #desktop_window_create_params_t.width
    lda [PARAMS],Y
    .AMAXU P_IMM WINDOW_MINIMUM_WIDTH
    .AMINU P_IMM WINDOW_MAXIMUM_WIDTH
    sta.l kWindowTabWidth,X
    lda #WINDOW_MAXIMUM_X
    sec
    sbc.l kWindowTabWidth,X
    inc A
    sta.b MAX_X
    ldy #desktop_window_create_params_t.height
    lda [PARAMS],Y
    .AMAXU P_IMM WINDOW_MINIMUM_HEIGHT
    .AMINU P_IMM WINDOW_MAXIMUM_HEIGHT
    sta.l kWindowTabHeight,X
    lda #WINDOW_MAXIMUM_Y
    sec
    sbc.l kWindowTabHeight,X
    inc A
    sta.b MAX_Y
    ldy #desktop_window_create_params_t.pos_x
    lda [PARAMS],Y
    .AMAXU P_IMM WINDOW_MINIMUM_X
    .AMINU P_DIR MAX_X
    sta.l kWindowTabPosX,X
    ldy #desktop_window_create_params_t.pos_y
    lda [PARAMS],Y
    .AMAXU P_IMM WINDOW_MINIMUM_Y
    .AMINU P_DIR MAX_Y
    sta.l kWindowTabPosY,X
; Mark tiles as dirty
    jsl windowMarkDirty__
; end
    sep #$30
    ldx.b CURRENT_WINDOW_ID
    .RestoreInt__
    rtl
    .UNDEFINE CURRENT_WINDOW_ID
    .UNDEFINE PARAMS
    .UNDEFINE MAX_X
    .UNDEFINE MAX_Y

; windowMarkDirty__([x8]WID window)
windowMarkDirty__:
    .DEFINE CURRENT_WINDOW_ID $00
    .DEFINE FROM_X $01
    .DEFINE FROM_Y $02
    .DEFINE END_X $03
    .DEFINE END_Y $04
    .DEFINE CURR_X $05
    .DEFINE CURR_Y $06
; setup variables
    sep #$30
    stx.b CURRENT_WINDOW_ID
    lda.l kWindowTabPosX,X
    sta.b FROM_X
    lda.l kWindowTabPosY,X
    sta.b FROM_Y
    lda.l kWindowTabWidth,X
    clc
    adc.b FROM_X
    sta.b END_X
    lda.l kWindowTabHeight,X
    clc
    adc.b FROM_Y
    sta.b END_Y
; iterate
    lda.b FROM_Y
    sta.b CURR_Y
    @iter_y:
        lda.b FROM_X
        sta.b CURR_X
        @iter_x:
            rep #$30
            ; X = tile index
            lda.b CURR_X
            and #$001F
            sta.l kTmpBuffer
            lda.b CURR_Y
            and #$001F
            asl
            asl
            asl
            asl
            asl
            ora.l kTmpBuffer
            tax
            tay
            sep #$20
            ; kWindowTileTabOwner[X] = win
            lda.b CURRENT_WINDOW_ID
            sta.l kWindowTileTabOwner,X
            ; if kWindowTileTabDirty[X]: continue
            lda.l kWindowTileTabDirty,X
            bne @skip
            ; kWindowTileTabDirty[X] = 1
            lda #1
            sta.l kWindowTileTabDirty,X
            ; kWIndowDirtyTileList[N] = X
            rep #$20
            lda.l kWindowNumDirtyTiles
            asl
            tax
            tya
            sta.l kWindowDirtyTileList,X
            ; ++ kWindowNumDirtyTiles
            lda.l kWindowNumDirtyTiles
            inc A
            sta.l kWindowNumDirtyTiles
        @skip:
            ; iter
            sep #$30
            lda.b CURR_X
            inc A
            sta.b CURR_X
            cmp.b END_X
            bcc @iter_x
        lda.b CURR_Y
        inc A
        sta.b CURR_Y
        cmp.b END_Y
        bcc @iter_y
    rtl
    .UNDEFINE CURRENT_WINDOW_ID
    .UNDEFINE FROM_X
    .UNDEFINE FROM_Y
    .UNDEFINE END_X
    .UNDEFINE END_Y
    .UNDEFINE CURR_X
    .UNDEFINE CURR_Y

windowDelete:
    rtl

windowRender__:
    rep #$30
    phb
    .ChangeDataBank $7E
    lda.w kWindowTileBufferSize
    beq @skip_write_tile_buffer
    stz.w kWindowTileBufferSize
    sta.l DMA0_SIZE
    lda #%0000100 + (256*lobyte(VMADDR))
    sta.l DMA0_CTL
    lda #loword(kWindowTileBuffer)
    sta.l DMA0_SRCL
    sep #$20 ; 8b A
    lda #bankbyte(kWindowTileBuffer)
    sta.l DMA0_SRCH
    lda #$01
    sta.l MDMAEN
@skip_write_tile_buffer:
; end
    plb
    rtl

_window_update_end_process_dirty_tiles:
; end
    plb
    rtl
windowUpdate__:
    .DEFINE CURR_TILE $00
    .DEFINE CURR_WINDOW $02
    .DEFINE TILE_X $03
    .DEFINE TILE_Y $04
    rep #$30 ; 16A 16XY
    phb
    .ChangeDataBank $7E
; process dirty tiles
@loop_process_dirty_tiles:
        rep #$30 ; 16A 16XY
        lda.w kWindowNumDirtyTiles
        beq _window_update_end_process_dirty_tiles ; no dirty tiles
        lda.w kWindowDrawBufferSize
        cmp #WINDOW_DRAW_BUFFER_TOTAL_SIZE
        bcs _window_update_end_process_dirty_tiles ; can't store more dirty tiles in buffer
    ; process single dirty tile
        ; --kWindowNumDirtyTiles
        dec.w kWindowNumDirtyTiles
        ; CURR_TILE = kWindowDirtyTileList[kWindowNumDirtyTiles.w]
        lda.w kWindowNumDirtyTiles
        asl
        tay
        lda.w kWindowDirtyTileList,Y
        sta.b CURR_TILE
        ; kWindowTileTabDirty[CURR_TILE] = 0
        tay
        sep #$20 ; 8A 16XY
        lda #0
        sta.w kWindowTileTabDirty,Y
        xba
        ; get owning window
        ldy.b CURR_TILE
        lda.w kWindowTileTabOwner,Y
        sta.b CURR_WINDOW
        tax ; X = WID
        ; parse tile location
        lda.b CURR_TILE
        and #$1F
        sta.b TILE_X
        rep #$20 ; 16A 16XY
        lda.b CURR_TILE
        lsr
        lsr
        lsr
        lsr
        lsr
        sep #$20 ; 8A 16XY
        and #$1F
        sta.b TILE_Y
        ; set tile address
        rep #$20 ; 16A 16XY
        lda.b CURR_TILE
        ldy.w kWindowTileBufferSize
        .IF DESKTOP_BG2_TILE_BASE_ADDR != 0
            clc
            adc #DESKTOP_BG2_TILE_BASE_ADDR
        .ENDIF
        sta.w kWindowTileBuffer.1.vramAddr,Y
        ; check if tile is on border of window
        sep #$20 ; 8A 16XY
        lda.w kWindowTabPosY,X
        cmp.b TILE_Y
        beq @border_top
        clc
        adc.w kWindowTabHeight,X
        dec A
        cmp.b TILE_Y
        beq @border_bottom
        lda.w kWindowTabPosX,X
        cmp.b TILE_X
        beql @border_side
        clc
        adc.w kWindowTabWidth,X
        dec A
        cmp.b TILE_X
        beql @border_side
        rep #$30 ; 16A 16XY
        ldx.w kWindowTileBufferSize
        lda #0
        sta.w kWindowTileBuffer.1.data,X
        jsr _window_process_inner
        jmp @end_process_tile
        @border_top:
            .ACCU 8
            .INDEX 16
            ; DO TOP BORDER
            lda.w kWindowTabPosX,X
            cmp.b TILE_X
            beq @corner
            clc
            adc.w kWindowTabWidth,X
            dec A
            cmp.b TILE_X
            beq @icon_delete
            dec A
            cmp.b TILE_X
            beq @icon_fullscreen
            dec A
            cmp.b TILE_X
            beq @icon_minimize
            jmp @border_vertical
        @icon_delete:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($26, 1)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @icon_fullscreen:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($22, 0)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @icon_minimize:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($24, 0)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @border_bottom:
            .ACCU 8
            .INDEX 16
            ; DO BOTTOM BORDER
            lda.w kWindowTabPosX,X
            cmp.b TILE_X
            beq @corner
            clc
            adc.w kWindowTabWidth,X
            dec A
            cmp.b TILE_X
            beq @corner
        @border_vertical:
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($04, 0)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @corner:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($02, 0)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @border_side:
            .ACCU 8
            .INDEX 16
            ; DO LEFT OR RIGHT BORDER (no corners)
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($06, 0)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
    @end_process_tile:
    ; increment kWindowTileBufferSize
        rep #$20
        lda.w kWindowTileBufferSize
        clc
        adc #_sizeof_window_tile_buffer_t
        sta.w kWindowTileBufferSize
    ; iter, maybe
        jmp @loop_process_dirty_tiles

_window_process_inner:
    ; TODO
    rts

.ENDS