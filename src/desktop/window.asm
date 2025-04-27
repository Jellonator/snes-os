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
            .dw DESKTOP_BG1_CHAR_BASE_ADDR
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
; set renderer for null tiles
    sep #$20
    lda #lobyte(_tilerender_clear)
    sta.w kWindowTabRenderFuncLow
    lda #hibyte(_tilerender_clear)
    sta.w kWindowTabRenderFuncPage
    lda #bankbyte(_tilerender_clear)
    sta.w kWindowTabRenderFuncBank
; set signal for null tiles
    lda #lobyte(_tilesignal_null)
    sta.w kWindowTabSignalFuncLow
    lda #hibyte(_tilesignal_null)
    sta.w kWindowTabSignalFuncPage
    lda #bankbyte(_tilesignal_null)
    sta.w kWindowTabSignalFuncBank
; set position of 'null' window to contain whole desktop area
    lda #1
    sta.w kWindowTabPosX+0
    sta.w kWindowTabPosY+1
    lda #30
    sta.w kWindowTabWidth
    lda #28
    sta.w kWindowTabHeight
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
; find free window ID (process is NULL) (where ID > 0)
    sep #$30
    ldx #0
@loop_find_window_id:
        inx
        lda.l kWindowTabProcess,X
        beq @found_window_id
        jmp @loop_find_window_id
@found_window_id:
    stx.b CURRENT_WINDOW_ID
; bump up each window ID (new window will take window order 0)
    lda.l kWindowNumWindows
    dec A
    tax
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
; Copy signal function into window
    ldy #desktop_window_create_params_t.signal
    lda [PARAMS],Y
    sta.l kWindowTabSignalFuncLow,X
    iny
    lda [PARAMS],Y
    sta.l kWindowTabSignalFuncPage,X
    iny
    lda [PARAMS],Y
    sta.l kWindowTabSignalFuncBank,X
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
    jsl windowUpdateOwnerAndMarkDirty__
; end
    sep #$30
    ldx.b CURRENT_WINDOW_ID
    .RestoreInt__
    rtl
    .UNDEFINE CURRENT_WINDOW_ID
    .UNDEFINE PARAMS
    .UNDEFINE MAX_X
    .UNDEFINE MAX_Y

; windowUpdateOwnerAndMarkDirty__([x8]WID window)
; Set all tiles in `window` as owned by `window`, and mark them as dirty.
windowUpdateOwnerAndMarkDirty__:
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

; windowMarkDirty__([x8]WID window)
; Mark all tiles in `window`'s bounds as dirty, without affecting any other data
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
    .DEFINE NUM_HANDLED $05
    .DEFINE FUNC kTmpBuffer
    rep #$30 ; 16A 16XY
    stz.b NUM_HANDLED
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
        lda.b NUM_HANDLED
        cmp #8
        bcc @ignore_scanline
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
        @ignore_scanline:
        inc.b NUM_HANDLED
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
        beql @border_bottom
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
        cpx #0
        beq +
            lda #deft($20, 4)
        +:
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
            xba
            lda #T_FLIPH>>8
            xba
            dec A
            cmp.b TILE_X
            beq @corner
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
            lda #deft($26, 1) | T_HIGHP
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @icon_fullscreen:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($22, 0) | T_HIGHP
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @icon_minimize:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            ldx.w kWindowTileBufferSize
            lda #deft($24, 0) | T_HIGHP
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
            ora #deft($04, 0) | T_HIGHP
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @corner:
            .ACCU 8
            .INDEX 16
            rep #$30 ; 16A 16XY
            and #$FF00
            ldx.w kWindowTileBufferSize
            ora #deft($02, 0) | T_HIGHP
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
        @border_side:
            .ACCU 8
            .INDEX 16
            ; DO LEFT OR RIGHT BORDER (no corners)
            rep #$30 ; 16A 16XY
            and #$FF00
            ldx.w kWindowTileBufferSize
            ora #deft($06, 0) | T_HIGHP
            sta.w kWindowTileBuffer.1.data,X
            jmp @end_process_tile
    @end_process_tile:
    ; increment kWindowTileBufferSize
        rep #$20
        lda.w kWindowTileBufferSize
        clc
        adc #_sizeof_window_tile_buffer_t
        sta.w kWindowTileBufferSize
    ; iter
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
    sec
    sbc.w kWindowTabPosX,X
    dec A
    pha
    lda.b TILE_Y
    sbc.w kWindowTabPosY,X
    sec
    dec A
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
    .UNDEFINE CURR_TILE
    .UNDEFINE CURR_WINDOW
    .UNDEFINE TILE_X
    .UNDEFINE TILE_Y
    .UNDEFINE FUNC

; [x8] window
; [a8] handlemask (0 means border was not clicked)
; windowHandleClick([s8]mousex, [s8]mousey)
; mousex $05,S
; mousey $04,S
windowHandleClick__:
    .DEFINE CURR_TILE $00
    .DEFINE WINDOW $02
    .DEFINE TILE_X $03
    .DEFINE TILE_Y $04
    .DEFINE FUNC kTmpBuffer
    phb
    .ChangeDataBank $7E
; get index of tile
    rep #$20
    lda 1+$05,S
    and #$00FF
    lsr
    lsr
    lsr
    sta.b CURR_TILE
    sep #$20
    sta.b TILE_X
    lda 1+$04,S
    and #$00FF
    lsr
    lsr
    lsr
    sta.b TILE_Y
    rep #$20
    xba
    lsr
    lsr
    lsr
    ora.b CURR_TILE
    sta.b CURR_TILE
; get window
    tax
    sep #$20 ; 8A 16XY
    lda.w kWindowTileTabOwner,X
    sta.b WINDOW
    sep #$10 ; 8A 8XY
    tax
    pei ($00)
    pei ($02)
    pei ($04)
    jsl kWindowMoveToFront__
    rep #$20
    pla
    sta.b $04
    pla
    sta.b $02
    pla
    sta.b $00
    sep #$30
    ldx.b WINDOW
; check where on window we have clicked
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
        beql @border_left
        clc
        adc.w kWindowTabWidth,X
        dec A
        cmp.b TILE_X
        beql @border_right
        rep #$30 ; 16A 16XY
        ; CLICKED INSIDE WINDOW
        jmp @end_process_tile
        @border_top:
            .ACCU 8
            .INDEX 8
            lda #0
            xba
            lda.w kWindowTabPosX,X
            cmp.b TILE_X
            beq @corner_top_left
            clc
            adc.w kWindowTabWidth,X
            dec A
            cmp.b TILE_X
            beq @corner_top_right
            dec A
            cmp.b TILE_X
            beq @icon_delete
            dec A
            cmp.b TILE_X
            beq @icon_fullscreen
            dec A
            cmp.b TILE_X
            beq @icon_minimize
            ; TOP BORDER CLICKED
            lda #WINDOW_HANDLEMASK_TOP
            jmp @end_process_tile_with_border
        @icon_delete:
            .ACCU 8
            .INDEX 8
            ; CLOSE CLICKED
            sep #$30
            ldx.b WINDOW
            jsl windowClose
            jmp @end_process_tile
        @icon_fullscreen:
            .ACCU 8
            .INDEX 8
            ; FULLSCREEN CLICKED
            jmp @end_process_tile
        @icon_minimize:
            .ACCU 8
            .INDEX 8
            ; MINIMIZE CLICKED
            jmp @end_process_tile
        @border_bottom:
            .ACCU 8
            .INDEX 8
            lda.w kWindowTabPosX,X
            cmp.b TILE_X
            beq @corner_bottom_left
            clc
            adc.w kWindowTabWidth,X
            dec A
            cmp.b TILE_X
            beq @corner_bottom_right
            ; BOTTOM SIDE CLICKED
            lda #WINDOW_HANDLEMASK_BOTTOM
            jmp @end_process_tile_with_border
        @corner_top_left:
            .ACCU 8
            .INDEX 8
            ; TOP LEFT CLICKED
            lda #WINDOW_HANDLEMASK_TOP | WINDOW_HANDLEMASK_LEFT
            jmp @end_process_tile_with_border
        @corner_top_right:
            .ACCU 8
            .INDEX 8
            ; TOP RIGHT CLICKED
            lda #WINDOW_HANDLEMASK_TOP | WINDOW_HANDLEMASK_RIGHT
            jmp @end_process_tile_with_border
        @corner_bottom_left:
            .ACCU 8
            .INDEX 8
            ; BOTTOM LEFT CLICKED
            lda #WINDOW_HANDLEMASK_BOTTOM | WINDOW_HANDLEMASK_LEFT
            jmp @end_process_tile_with_border
        @corner_bottom_right:
            .ACCU 8
            .INDEX 8
            ; BOTTOM RIGHT CLICKED
            lda #WINDOW_HANDLEMASK_BOTTOM | WINDOW_HANDLEMASK_RIGHT
            jmp @end_process_tile_with_border
        @border_left:
            .ACCU 8
            .INDEX 8
            ; LEFT BORDER CLICKED
            lda #WINDOW_HANDLEMASK_LEFT
            jmp @end_process_tile_with_border
        @border_right:
            .ACCU 8
            .INDEX 8
            ; RIGHT BORDER CLICKED
            lda #WINDOW_HANDLEMASK_RIGHT
            jmp @end_process_tile_with_border
@end_process_tile:
    plb
    sep #$30
    ldx.b WINDOW
    lda #0
    rtl
@end_process_tile_with_border:
    plb
    sep #$30
    rtl
    .UNDEFINE CURR_TILE
    .UNDEFINE WINDOW
    .UNDEFINE TILE_X
    .UNDEFINE TILE_Y
    .UNDEFINE FUNC

; kWindowMoveToFront__([x8]WID window)
; Move window to front
kWindowMoveToFront__
    sep #$30
    cpx.w kWindowOrder
    beq @end ; already in front
    cpx #0
    beq @end ; user clicked on background - NEVER BRING BACKGROUND TO FRONT
; Find this window's location in order
    txa
    txy
    ldx #1
    @loop_search_window:
        cmp.w kWindowOrder,X
        beq @found_window
        inx
        jmp @loop_search_window
    @found_window:
; Move everything down
    @loop_copy_windows:
        lda.w kWindowOrder-1,X
        sta.w kWindowOrder,X
        dex
        bne @loop_copy_windows
; Set kWindowOrder[0] to WID
    sty.w kWindowOrder
; take ownership of front tiles and re-render window
    tyx
    jsl windowUpdateOwnerAndMarkDirty__
@end:
    rtl

_window_close_cancel:
    sep #$30
    .RestoreInt__
    plb
    rtl
; windowClose([x8]WID window)
windowClose:
    .DEFINE CURRENT_WINDOW_ID $00
    .DEFINE TMP $02
    sep #$30
    phb
    .ChangeDataBank $7E
    .DisableInt__
    ; check that window is open and valid
    lda.w kWindowTabProcess,X
    beq _window_close_cancel ; window is not active: cancel
    stx.b CURRENT_WINDOW_ID
    lda.w kWindowNumWindows
    cpx #0
    beq _window_close_cancel ; WID is null: cancel
    ; TODO: signal window owner
    ; Mark window area as dirty
    jsl windowMarkDirty__
; Find index of window in order
    sep #$30
    ldx #-1
    @loop_find_window:
        inx
        lda.w kWindowOrder,X
        cmp.b CURRENT_WINDOW_ID
        bne @loop_find_window
    ; kWindowOrder[X] == WID
; decrement number of windows
    lda.w kWindowNumWindows
    dec A
    sta.w kWindowNumWindows
    sta.b TMP
; shift windows from X+1 to X
    @loop_copy_order:
        cpx.b TMP
        beq @skip_copy_order
        lda.w kWindowOrder+1,X
        sta.w kWindowOrder,X
        inx
        jmp @loop_copy_order
    @skip_copy_order:
; set process to 'null'
    lda #0
    ldx.b CURRENT_WINDOW_ID
    sta.w kWindowTabProcess,X
; Determine new owners of freed tiles
    jsl windowDetermineDirtyOwners__
    sep #$30
    .RestoreInt__
    plb
    rtl
    .UNDEFINE CURRENT_WINDOW_ID

windowDetermineDirtyOwners__:
    .ACCU 8
    .INDEX 8
    rep #$30
    .DEFINE CURR_TILE_INDEX $00
    .DEFINE CURR_TILE $02
    .DEFINE TILE_X $04
    .DEFINE TILE_Y $05
    ; for each tile in dirty tile list, iterate order to find first window
    ; which captures this tile.
    lda.w kWindowNumDirtyTiles
    asl
    dec A
    dec A
    sta.b CURR_TILE_INDEX
    @loop_dirty_tiles:
        ldx.b CURR_TILE_INDEX
        lda.w kWindowDirtyTileList,X
        sta.b CURR_TILE
        and #$1F
        sta.b TILE_X
        lda.b CURR_TILE
        and #$3E0
        lsr
        lsr
        lsr
        lsr
        lsr
        sta.b TILE_Y
        ; begin checking windows
        sep #$30
        ldy #-1
        @loop_window_order:
            iny
            cpy.w kWindowNumWindows
            bcs @end_loop_window_order_null
            ldx.w kWindowOrder,Y
            lda.w kWindowTabPosX,X
            cmp.b TILE_X
            bgru @loop_window_order
            clc
            adc.w kWindowTabWidth,X
            cmp.b TILE_X
            bleu @loop_window_order
            lda.w kWindowTabPosY,X
            cmp.b TILE_Y
            bgru @loop_window_order
            clc
            adc.w kWindowTabHeight,X
            cmp.b TILE_Y
            bleu @loop_window_order
            ; FOUND TILE: X=WID, Y=INDEX
            jmp @end_loop_window_order_found
        @end_loop_window_order_null:
            ldx #0
        @end_loop_window_order_found:
        ; kWindowTileTabOwner[CURR_TILE] = WID
        txa ; A=WID
        rep #$10
        ldx.b CURR_TILE ; X=CURR_TILE
        sta.w kWindowTileTabOwner,X
        rep #$20
        ; while(--CURR_TILE_INDEX >= 0)
        dec.b CURR_TILE_INDEX
        dec.b CURR_TILE_INDEX
        bpl @loop_dirty_tiles
    @end_loop_dirty_tiles:
    rtl
    .UNDEFINE CURR_TILE_INDEX $00

; Set borders matching mask to given position
; kWindowProcessDrag__([s8]int dragmask, [s8]WID window, [s8]int tilex, [s8]int tiley, [s8]int prevtilex, [s8] prevtiley)
; dragmask $09,S
; window $08,S
; tilex $07,S
; tiley $06,S
; prevtilex $05,S
; prevtiley $04,S
kWindowProcessDrag__:
    .DEFINE DID_CHANGE $00
    .DEFINE NEW_X $01
    .DEFINE NEW_Y $02
    .DEFINE NEW_W $03
    .DEFINE NEW_H $04
    .DEFINE MINV $05
    .DEFINE MAXV $06
    .DEFINE TEMP $07
    ; if there are at least 8 dirty tiles, then skip drag. Might change in the future
    rep #$20
    lda.l kWindowNumDirtyTiles
    cmp #8
    bcc +
        sep #$30
        lda #0
        rtl
    +:
    sep #$30
    phb
    .ChangeDataBank $7E
    stz.b DID_CHANGE
; copy values
    lda 1+$08,S
    tax
    lda.w kWindowTabPosX,X
    sta.b NEW_X
    lda.w kWindowTabPosY,X
    sta.b NEW_Y
    lda.w kWindowTabWidth,X
    sta.b NEW_W
    lda.w kWindowTabHeight,X
    sta.b NEW_H
; do process steps according to mask
    lda 1+$09,S
    cmp #WINDOW_HANDLEMASK_TOP
    bne +
        jsr _process_drag_window
        sep #$30
        jmp @skip_rest_handlers
    +:
    bit #WINDOW_HANDLEMASK_LEFT
    beq +
        jsr _process_drag_left
        sep #$30
    +:
    lda 1+$09,S
    bit #WINDOW_HANDLEMASK_RIGHT
    beq +
        jsr _process_drag_right
        sep #$30
    +:
    lda 1+$09,S
    bit #WINDOW_HANDLEMASK_TOP
    beq +
        jsr _process_drag_top
        sep #$30
    +:
    lda 1+$09,S
    bit #WINDOW_HANDLEMASK_BOTTOM
    beq +
        jsr _process_drag_bottom
        sep #$30
    +:
; check if work was done
@skip_rest_handlers:
    lda.b DID_CHANGE
    beq @skip_do_work
    ; mark previous window area as dirty
    rep #$20
    lda.b $01
    pha
    lda.b $03
    pha
    jsl windowMarkDirty__
    rep #$20
    pla
    sta.b $03
    pla
    sta.b $01
    ; copy data into value
    sep #$30
    lda 1+$08,S
    tax
    lda.b NEW_X
    sta.w kWindowTabPosX,X
    lda.b NEW_Y
    sta.w kWindowTabPosY,X
    lda.b NEW_W
    sta.w kWindowTabWidth,X
    lda.b NEW_H
    sta.w kWindowTabHeight,X
    ; mark new window area as dirty, and take ownership of new area
    jsl windowUpdateOwnerAndMarkDirty__
    ; TODO: make more efficient, somehow?
    jsl windowDetermineDirtyOwners__
@skip_do_work:
; end
    sep #$30
    plb
    lda #1
    rtl

; dragmask $0B,S
; window $0A,S
; tilex $09,S
; tiley $08,S
; prevtilex $07,S
; prevtiley $06,S
_process_drag_left:
    .ACCU 8
    .INDEX 8
; determine acceptable min and max
    ; MIN = WINDOW_BORDER_MINIMUM_X
    lda #WINDOW_BORDER_MINIMUM_X
    sta.b MINV
    ; MAX = (window.x + window.width - WINDOW_BORDER_MINIMUM_WIDTH)
    lda.w kWindowTabPosX,X
    clc
    adc.w kWindowTabWidth,X
    sta.b TEMP
    sec
    sbc #WINDOW_BORDER_MINIMUM_WIDTH
    sta.b MAXV
; get tile, and clamp
    lda 1+$09,S
    .AMINU P_DIR MAXV
    .AMAXU P_DIR MINV
    cmp.b NEW_X
    beq @skip
    ; new tile position is different, indicate this
        sta.b NEW_X
        lda.b TEMP
        sec
        sbc.b NEW_X
        sta.b NEW_W
        inc.b DID_CHANGE
@skip:
    rts

; dragmask $0B,S
; window $0A,S
; tilex $09,S
; tiley $08,S
; prevtilex $07,S
; prevtiley $06,S
_process_drag_right:
    .ACCU 8
    .INDEX 8
; determine acceptable min and max
    ; MIN = (window.x + WINDOW_BORDER_MINIMUM_WIDTH - 1)
    lda.w kWindowTabPosX,X
    clc
    adc #WINDOW_BORDER_MINIMUM_WIDTH-1
    sta.b MINV
    ; MAX = WINDOW_BORDER_MAXIMUM_X
    lda #WINDOW_BORDER_MAXIMUM_X
    sta.b MAXV
; get tile, and clamp
    lda 1+$09,S
    .AMINU P_DIR MAXV
    .AMAXU P_DIR MINV
    ; NEW_W = TILE_X - window.x + 1
    sec
    sbc.w kWindowTabPosX,X
    inc A
    cmp.b NEW_W
    beq @skip
    ; new tile position is different, indicate this
        sta.b NEW_W
        inc.b DID_CHANGE
@skip:
    rts

; dragmask $0B,S
; window $0A,S
; tilex $09,S
; tiley $08,S
; prevtilex $07,S
; prevtiley $06,S
_process_drag_top:
    .ACCU 8
    .INDEX 8
; determine acceptable min and max
    ; MIN = WINDOW_BORDER_MINIMUM_Y
    lda #WINDOW_BORDER_MINIMUM_Y
    sta.b MINV
    ; MAX = (window.y + window.height - WINDOW_BORDER_MINIMUM_HEIGHT)
    lda.w kWindowTabPosY,X
    clc
    adc.w kWindowTabHeight,X
    sta.b TEMP
    sec
    sbc #WINDOW_BORDER_MINIMUM_HEIGHT
    sta.b MAXV
; get tile, and clamp
    lda 1+$08,S
    .AMINU P_DIR MAXV
    .AMAXU P_DIR MINV
    cmp.b NEW_Y
    beq @skip
    ; new tile position is different, indicate this
        sta.b NEW_Y
        lda.b TEMP
        sec
        sbc.b NEW_Y
        sta.b NEW_H
        inc.b DID_CHANGE
@skip:
    rts

; dragmask $0B,S
; window $0A,S
; tilex $09,S
; tiley $08,S
; prevtilex $07,S
; prevtiley $06,S
_process_drag_bottom:
    .ACCU 8
    .INDEX 8
; determine acceptable min and max
    ; MIN = (window.y + WINDOW_BORDER_MINIMUM_HEIGHT - 1)
    lda.w kWindowTabPosY,X
    clc
    adc #WINDOW_BORDER_MINIMUM_HEIGHT-1
    sta.b MINV
    ; MAX = WINDOW_BORDER_MAXIMUM_Y
    lda #WINDOW_BORDER_MAXIMUM_Y
    sta.b MAXV
; get tile, and clamp
    lda 1+$08,S
    .AMINU P_DIR MAXV
    .AMAXU P_DIR MINV
    ; NEW_W = TILE_X - window.x + 1
    sec
    sbc.w kWindowTabPosY,X
    inc A
    cmp.b NEW_H
    beq @skip
    ; new tile position is different, indicate this
        sta.b NEW_H
        inc.b DID_CHANGE
@skip:
    rts

; special case: drag whole window
; dragmask $0B,S
; window $0A,S
; tilex $09,S
; tiley $08,S
; prevtilex $07,S
; prevtiley $06,S
_process_drag_window:
    .ACCU 8
    .INDEX 8
; move X
    ; determine acceptable min and max
    ; MIN = WINDOW_BORDER_MINIMUM_X
    lda #WINDOW_BORDER_MINIMUM_X
    sta.b MINV
    ; MAX = (WINDOW_BORDER_MAXIMUM_X - window.width + 1)
    lda #WINDOW_BORDER_MAXIMUM_X
    sec
    sbc.w kWindowTabWidth,X
    inc A
    sta.b MAXV
    ; get tile, and clamp
    lda 1+$09,S
    sec
    sbc 1+$07,S
    clc
    adc.b NEW_X
    .AMINU P_DIR MAXV
    .AMAXU P_DIR MINV
    cmp.b NEW_X
    beq @skipx
    ; new tile position is different, indicate this
        sta.b NEW_X
        inc.b DID_CHANGE
@skipx:
; move Y
    ; determine acceptable min and max
    ; MIN = WINDOW_BORDER_MINIMUM_Y
    lda #WINDOW_BORDER_MINIMUM_Y
    sta.b MINV
    ; MAX = (window.y + window.height - WINDOW_BORDER_MINIMUM_HEIGHT)
    lda #WINDOW_BORDER_MAXIMUM_Y
    sec
    sbc.w kWindowTabHeight,X
    inc A
    sta.b MAXV
    ; get tile, and clamp
    lda 1+$08,S
    sec
    sbc 1+$06,S
    clc
    adc.b NEW_Y
    .AMINU P_DIR MAXV
    .AMAXU P_DIR MINV
    cmp.b NEW_Y
    beq @skipy
    ; new tile position is different, indicate this
        sta.b NEW_Y
        inc.b DID_CHANGE
@skipy:
    rts

.UNDEFINE DID_CHANGE
.UNDEFINE NEW_X
.UNDEFINE NEW_Y
.UNDEFINE NEW_W
.UNDEFINE NEW_H
.UNDEFINE MINV
.UNDEFINE MAXV
.UNDEFINE TEMP

; renderTile([x16]WID window, [By16]void* buffer, [s8]int x, [s8] int y)
; buffer[  0.. 32] is first tile,
; buffer[ 32.. 64] is second tile
; buffer[ 64.. 96] is third tile
; buffer[ 96..128] is fourth tile.
; Each tile has four bitplanes: 0101010101010101,2323232323232323
_tilerender_clear:
    .ACCU 16
    .INDEX 16
    ; clear whole tile
    lda #$0000
    ldx #128/2
    @loop:
        sta.w $0000,Y
        iny
        iny
        dex
        bne @loop
    rtl

_tilesignal_null:
    rtl

.ENDS