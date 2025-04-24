.include "base.inc"

.BANK $02 SLOT "ROM"
.SECTION "Windowing" FREE

; this section is synonymous with `desktop.asm::_default_bg1_tiles`.
; the main difference is that we do not loop addresses.
.DEFINE INDEX 0
_target_address_for_tile:
.REPT 32 INDEX iy
    .REPT 32 INDEX ix
        .IF ix < WINDOW_CONTENT_MINIMUM_X || ix > WINDOW_CONTENT_MAXIMUM_X || iy < WINDOW_CONTENT_MINIMUM_Y || iy > WINDOW_CONTENT_MAXIMUM_Y
            .dw 0
        .ELSE
            .IF (INDEX #$0300) == 0
                .REDEFINE INDEX (INDEX + $02)
            .ENDIF
            .dw INDEX * $10 + DESKTOP_BG1_CHAR_BASE_ADDR
            .IF (INDEX#$10) == $0E
                .REDEFINE INDEX (INDEX + $12)
            .ELSE
                .REDEFINE INDEX (INDEX + $02)
            .ENDIF
        .ENDIF
    .ENDR
.ENDR
.UNDEFINE INDEX

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
    .AMAXU P_IMM WINDOW_BORDER_MINIMUM_WIDTH
    .AMINU P_IMM WINDOW_BORDER_WIDTH_TILES
    sta.l kWindowTabWidth,X
    lda #WINDOW_BORDER_MAXIMUM_X
    sec
    sbc.l kWindowTabWidth,X
    inc A
    sta.b MAX_X
    ldy #desktop_window_create_params_t.height
    lda [PARAMS],Y
    .AMAXU P_IMM WINDOW_BORDER_MINIMUM_HEIGHT
    .AMINU P_IMM WINDOW_CONTENT_HEIGHT_TILES
    sta.l kWindowTabHeight,X
    lda #WINDOW_BORDER_MAXIMUM_Y
    sec
    sbc.l kWindowTabHeight,X
    inc A
    sta.b MAX_Y
    ldy #desktop_window_create_params_t.pos_x
    lda [PARAMS],Y
    .AMAXU P_IMM WINDOW_BORDER_MINIMUM_X
    .AMINU P_DIR MAX_X
    sta.l kWindowTabPosX,X
    ldy #desktop_window_create_params_t.pos_y
    lda [PARAMS],Y
    .AMAXU P_IMM WINDOW_BORDER_MINIMUM_Y
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
; write tile buffer
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
; write char buffer. Trust that we can upload the whole thing, since it is limited to 8K
    rep #$30
    lda.w kWindowDrawBufferSize
    beq @end_write_char_buffer
    stz.w kWindowDrawBufferSize
    tay
    ldx #0
    lda #$7E
    sta.l DMA0_SRCH
    lda #(%00000001 + ($0100 * $18))
    sta.l DMA0_CTL
    lda #kWindowDrawBuffer
    sta.l DMA0_SRCL
@loop_write_char_buffer:
        lda.w kWindowDrawBufferTargetAddr,X
        sta.l VMADDR
        lda #64
        sta.l DMA0_SIZE
        lda #$0100
        sta.l MDMAEN-1
        lda.w kWindowDrawBufferTargetAddr,X
        clc
        adc #$0100
        sta.l VMADDR
        lda #64
        sta.l DMA0_SIZE
        lda #$0100
        sta.l MDMAEN-1
        inx
        inx
        dey
        bne @loop_write_char_buffer
@end_write_char_buffer:
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
    .DEFINE FUNC kTmpBuffer
    rep #$30 ; 16A 16XY
    phb
    .ChangeDataBank $7E
; process dirty tiles
@loop_process_dirty_tiles:
        rep #$30 ; 16A 16XY
        lda.w kWindowNumDirtyTiles
        beq _window_update_end_process_dirty_tiles ; no dirty tiles
        lda.w kWindowDrawBufferSize
        cmp #WINDOW_DRAW_BUFFER_ELEMENTS_LIMIT
        bcs _window_update_end_process_dirty_tiles ; can't store more dirty tiles in buffer
        ; check scanline. Since we are in a disableInt__ block, need to make
        ; sure we don't skip IRQ. Not a perfect process, but ensures all of our
        ; execution time isn't dedicated to processing dirty tiles.
        ; This does run a slight risk of slowing down the processing of tiles.
        sep #$20
        lda.l SLHV
        lda.l SCANLINE_V
        sta.l kTmpBuffer
        lda.l SCANLINE_V
        and #$01
        sta.l kTmpBuffer+1
        rep #$20
        lda.l kTmpBuffer
        cmp #180
        bcc +
        cmp #225
        bcs +
            jmp _window_update_end_process_dirty_tiles
        +:
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
        lda #0
        xba
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
        xba
        lda #T_FLIPH>>8
        xba
        clc
        adc.w kWindowTabWidth,X
        dec A
        cmp.b TILE_X
        beql @border_side
        rep #$30 ; 16A 16XY
        ldy.w kWindowTileBufferSize
        lda #0
        sta.w kWindowTileBuffer.1.data,Y
        jsr _window_process_inner
        jmp @end_process_tile
        @border_top:
            .ACCU 8
            .INDEX 16
            ; DO TOP BORDER
            lda #0
            xba
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
            lda #0
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
            lda #T_FLIPV>>8
            xba
            lda.w kWindowTabPosX,X
            cmp.b TILE_X
            beq @corner
            xba
            ora #T_FLIPH>>8
            xba
            clc
            adc.w kWindowTabWidth,X
            dec A
            cmp.b TILE_X
            beq @corner
            lda #T_FLIPV>>8
            xba
        @border_vertical:
            rep #$30 ; 16A 16XY
            and #$FF00
            ldx.w kWindowTileBufferSize
            ora #deft($04, 0)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @corner:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            and #$FF00
            ldx.w kWindowTileBufferSize
            ora #deft($02, 0)
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @border_side:
            .ACCU 8
            .INDEX 16
            ; DO LEFT OR RIGHT BORDER (no corners)
            rep #$30 ; 16A 16XY
            and #$FF00
            ldx.w kWindowTileBufferSize
            ora #deft($06, 0)
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
    phd
; set up function pointer in direct page
    sep #$30
    lda.w kWindowTabRenderFuncLow,X
    sta.w FUNC+0
    lda.w kWindowTabRenderFuncPage,X
    sta.w FUNC+1
    lda.w kWindowTabRenderFuncBank,X
    sta.w FUNC+2
; push tile position
    lda.b TILE_X
    pha
    lda.b TILE_Y
    pha
; set direct page to that of process
    ldy.w kWindowTabProcess,X
    rep #$30
    lda.w kProcTabDirectPageIndex,Y
    and #$00FF
    asl
    asl
    asl
    asl
    asl
    tcd
; Y = buffer pointer
    lda.w kWindowDrawBufferSize
    xba
    lsr ; A×=128
    clc
    adc #kWindowDrawBuffer
    tay
; call function
    phk
    pea @postfunc - 1
    jmp.w [FUNC]
@postfunc:
    nop
    ; pop
    .POPN 2
    pld
; schedule upload
    rep #$30
    lda.w kWindowDrawBufferSize
    asl
    tay
    inc.w kWindowDrawBufferSize
    lda.b CURR_TILE
    asl
    tax
    lda.l _target_address_for_tile,X
    sta.w kWindowDrawBufferTargetAddr,Y
; end
    rts

.ENDS