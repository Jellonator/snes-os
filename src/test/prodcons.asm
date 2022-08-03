.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "TestProdcons" FREE

.STRUCT ProdconData
    data dw
    semCanRead db
    semCanWrite db
    semFinish db
    count dw
.ENDST

_testConsumer_name: .db "cons\0"
_testConsumer:
    ; jsl procExit
    rep #$30
    plx
    stx.b $06 ; $06: &ProdconData
    lda.w ProdconData.count,X
    sta.b $08 ; $08: count
    sep #$20
    lda.w ProdconData.semCanRead,X
    sta.b $10 ; $10: sid8 canread
    lda.w ProdconData.semCanWrite,X
    sta.b $11 ; $11: sid8 canwrite
    lda.w ProdconData.semFinish,X
    sta.b $12 ; $12: sid8 finish
    pea 16
    jsl memAlloc
    stx.b $14 ; $14: string buffer
    rep #$20
    pla
; begin
@loop:
    sep #$20
    ldx.b $10
    jsl semWait
    .PrintStringLiteral "Consumed: \0"
    rep #$30
    lda.b ($06)
    ldx.b $14
    jsl writeU16
    ldy.b $14
    jsl kPutString
    sep #$20
    lda #'\n'
    jsl kPutC
    sep #$20
    ldx.b $11
    jsl semSignal
    sep #$20
    dec.b $08
    bne @loop
; end
    sep #$20
    ldx.b $12
    jsl semSignal
    jsl procExit

_testProducer_name: .db "prod\0"
_testProducer:
    ; jsl procExit
    rep #$30
    plx
    stx.b $06 ; $06: &ProdconData
    lda.w ProdconData.count,X
    sta.b $08 ; $08: count
    sep #$20
    lda.w ProdconData.semCanRead,X
    sta.b $10 ; $10: sid8 canread
    lda.w ProdconData.semCanWrite,X
    sta.b $11 ; $11: sid8 canwrite
    lda.w ProdconData.semFinish,X
    sta.b $12 ; $12: sid8 finish
    pea 16
    jsl memAlloc
    stx.b $14 ; $14: string buffer
    rep #$20
    pla
; begin
@loop:
    sep #$20
    ldx.b $11
    jsl semWait
    .PrintStringLiteral "Produced: \0"
    rep #$30
    lda.b $08
    sta.b ($06)
    ldx.b $14
    jsl writeU16
    ldy.b $14
    jsl kPutString
    sep #$20
    lda #'\n'
    jsl kPutC
    sep #$20
    ldx.b $10
    jsl semSignal
    sep #$20
    dec.b $08
    bne @loop
; end
    sep #$20
    ldx.b $12
    jsl semSignal
    jsl procExit

shTestProdcons_name: .db "prodcons\0"
shTestProdcons:
    rep #$30
    ; parse input count (argv[1])
    lda $03,s
    tax
    lda.w 2,X
    tax
    jsl stringToU16
    sta.b $10
    ; allocate data
    pea _sizeof_ProdconData
    jsl memAlloc
    stx.b $08
    rep #$30
    pla
    ; put A into data
    lda.b $10
    sta.w ProdconData.count,X
    ; create semaphores
    sep #$20
    lda #0
    jsl semCreate
    rep #$10
    txa
    ldx.b $08
    sta.w ProdconData.semCanRead,X
    sep #$20
    lda #1
    jsl semCreate
    txa
    rep #$10
    ldx.b $08
    sta.w ProdconData.semCanWrite,X
    sep #$20
    lda #0
    jsl semCreate
    txa
    rep #$10
    ldx.b $08
    sta.w ProdconData.semFinish,X
    ; push data pointer
    rep #$20
    lda.b $08
    pha
    ; create producer and consumer
    .CreateReadyProcess _testConsumer, 32, 2, _testConsumer_name
    .CreateReadyProcess _testProducer, 32, 2, _testProducer_name
    ; wait for finish
    .REPT 2
        rep #$10 ; 16b X
        ldx.b $08
        lda.w ProdconData.semFinish,X
        sep #$30 ; 8b AXY
        tax
        jsl semWait
    .ENDR
    ; exit
    .PrintStringLiteral "prodcons finished\n\0"
    jsl procExit

.ENDS