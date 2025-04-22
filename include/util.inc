; as a general rule, macro labels should begin with @@@@@
; that way, these labels don't mess with those in code

; META INSTRUCTIONS

; BRANCH EQUAL LONG
.MACRO beql ARGS addr
    bne +++++
        jmp addr
    +++++:
.ENDM
; BRANCH NOT EQUAL LONG
.MACRO bnel ARGS addr
    beq +++++
        jmp addr
    +++++:
.ENDM
; BRANCH CARRY CLEAR LONG
.MACRO bccl ARGS addr
    bcs +++++
        jmp addr
    +++++:
.ENDM
; BRANCH CARRY SET LONG
.MACRO bcsl ARGS addr
    bcc +++++
        jmp addr
    +++++:
.ENDM
; BRANCH OVERFLOW CLEAR LONG
.MACRO bvcl ARGS addr
    bvs +++++
        jmp addr
    +++++:
.ENDM
; BRANCH OVERFLOW SET LONG
.MACRO bvsl ARGS addr
    bvc +++++
        jmp addr
    +++++:
.ENDM
; BRANCH MINUS LONG / BRANCH NEGATIVE SET LONG
.MACRO bmil ARGS addr
    bpl +++++
        jmp addr
    +++++:
.ENDM
; BRANCH PLUS LONG / BRANCH NEGATIVE CLEAR LONG
.MACRO bpll ARGS addr
    bmi +++++
        jmp addr
    +++++:
.ENDM
; BRANCH LESS THAN UNSIGNED
.MACRO blsu ARGS addr
    bcc addr
.ENDM
; BRANCH LESS THAN SIGNED
.MACRO blss ARGS addr
    bmi addr
.ENDM
; BRANCH LESS THAN OR EQUAL UNSIGNED
.MACRO bleu ARGS addr
    bcc addr
    beq addr
.ENDM
; BRANCH LESS THAN OR EQUAL SIGNED
.MACRO bles ARGS addr
    bmi addr
    beq addr
.ENDM
; BRANCH GREATER THAN UNSIGNED
.MACRO bgru ARGS addr
    beq +++++
        bcs addr
    +++++:
.ENDM
; BRANCH GREATER THAN SIGNED
.MACRO bgrs ARGS addr
    beq +++++
        bpl addr
    +++++:
.ENDM
; BRANCH GREATER THAN OR EQUAL UNSIGNED
.MACRO bgeu ARGS addr
    bcs addr
.ENDM
; BRANCH GREATER THAN OR EQUAL SIGNED
.MACRO bges ARGS addr
    bpl addr
.ENDM
; BRANCH LESS THAN UNSIGNED LONG
.MACRO blsul ARGS addr
    bccl addr
.ENDM
; BRANCH LESS THAN SIGNED LONG
.MACRO blssl ARGS addr
    bmil addr
.ENDM
; BRANCH LESS THAN OR EQUAL UNSIGNED LONG
.MACRO bleul ARGS addr
    bccl addr
    beql addr
.ENDM
; BRANCH LESS THAN OR EQUAL SIGNED LONG
.MACRO blesl ARGS addr
    bmil addr
    beql addr
.ENDM
; BRANCH GREATER THAN UNSIGNED LONG
.MACRO bgrul ARGS addr
    beq +++++
        bcsl addr
    +++++:
.ENDM
; BRANCH GREATER THAN SIGNED LONG
.MACRO bgrsl ARGS addr
    beq +++++
        bpll addr
    +++++:
.ENDM
; BRANCH GREATER THAN OR EQUAL UNSIGNED LONG
.MACRO bgeul ARGS addr
    bcsl addr
.ENDM
; BRANCH GREATER THAN OR EQUAL SIGNED LONG
.MACRO bgesl ARGS addr
    bpll addr
.ENDM

; GENERIC INSTRUCTIONS

; Generic instruction types
.ENUMID 0
.ENUMID P_IMM
.ENUMID P_ABS
.ENUMID P_ABS_X
.ENUMID P_ABS_Y
.ENUMID P_ABS_IND
.ENUMID P_ABS_INDL
.ENUMID P_DIR
.ENUMID P_DIR_X
.ENUMID P_DIR_Y
.ENUMID P_DIR_IND
.ENUMID P_DIR_INDL
.ENUMID P_DIR_X_IND
.ENUMID P_DIR_IND_Y
.ENUMID P_DIR_INDL_Y
.ENUMID P_LONG
.ENUMID P_LONG_X
.ENUMID P_STACK
.ENUMID P_STACK_IND_Y
.ENUMID P_IMPLIED
.ENUMID P_REL8
.ENUMID P_REL16
.ENUMID P_SRC_DEST

; Generic Instruction invocation
; Note that many instruction,method pairs are invalid.
; Parameters:
;   inst   - the instruction
;   method - address mode
;   arg    - address/value
.MACRO .g_instruction ARGS inst method arg
    .IF method == P_IMM
        \1 #arg
    .ELIF method == P_ABS
        \1.w arg
    .ELIF method == P_ABS_X
        \1.w arg,X
    .ELIF method == P_ABS_Y
        \1.w arg,Y
    .ELIF method == P_ABS_IND
        \1.w (arg)
    .ELIF method == P_ABS_INDL
        \1.w [arg]
    .ELIF method == P_DIR
        \1.b arg
    .ELIF method == P_DIR_X
        \1.b arg,X
    .ELIF method == P_DIR_Y
        \1.b arg,Y
    .ELIF method == P_DIR_IND
        \1.b (arg)
    .ELIF method == P_DIR_INDL
        \1.b [arg]
    .ELIF method == P_DIR_X_IND
        \1.b (arg,X)
    .ELIF method == P_DIR_IND_Y
        \1.b (arg),Y
    .ELIF method == P_DIR_INDL_Y
        \1.b [arg],Y
    .ELIF method == P_LONG
        \1.l arg
    .ELIF method == P_LONG_X
        \1.l arg,X
    .ELIF method == P_STACK
        \1 arg,S
    .ELIF method == P_STACK_IND_Y
        \1 (arg,S),Y
    .ELIF method == P_REL8 || method == P_REL16
        \1 arg
    .ELIF method == P_IMPLIED || method == P_SRC_DEST
        .FAIL "Incompatible addressing mode"
    .ELSE
        .FAIL "Invalid addressing mode"
    .ENDIF
.ENDM

; Generic signed MAXIMUM
.MACRO .AMAX ARGS method arg
    sec
    .g_instruction sbc, method, arg
    bvs @@@@@@\.\@invert
    bpl @@@@@@\.\@restore
@@@@@@\.\@load:
    .g_instruction lda, method, arg
    bra @@@@@@\.\@end
@@@@@@\.\@invert:
    bpl @@@@@@\.\@load
@@@@@@\.\@restore:
    clc
    .g_instruction adc, method, arg
@@@@@@\.\@end:
.ENDM

; Generic signed MINIMUM
.MACRO .AMIN ARGS method, arg
    sec
    .g_instruction sbc, method, arg
    bvs @@@@@@\.\@invert
    bmi @@@@@@\.\@restore
@@@@@@\.\@load:
    .g_instruction lda, method, arg
    bra @@@@@@\.\@end
@@@@@@\.\@invert:
    bmi @@@@@@\.\@load
@@@@@@\.\@restore:
    clc
    .g_instruction adc, method, arg
@@@@@@\.\@end:
.ENDM

; Generic unsigned MAXIMUM
.MACRO .AMAXU ARGS method, addr
    .g_instruction cmp, method, addr
    bcs @@@@@\.\@
        .g_instruction lda, method, addr
    @@@@@\.\@:
.ENDM

; Generic unsigned MINIMUM
.MACRO .AMINU ARGS method, addr
    .g_instruction cmp, method, addr
    bcc @@@@@\.\@
        .g_instruction lda, method, addr
    @@@@@\.\@:
.ENDM

; Calculate the absolute value of A, in 16b mode
; ONLY use after an instruction that loads the value into A (checks N flag)
; e.g.: ADC, SBC, DEC, INC, AND, ORA, EOR, ASL, LSR, ROL, ROR, LDA, PLA, TXA, and TYA
; some other instructions also set the N flag but may either refer to a
; different register (e.g. LDX), or don't reflect the current value of A (e.g. CMP)
.MACRO .ABS_A16_POSTLOAD
    bpl @@@@@\.\@
    eor.w #$FFFF
    inc A
@@@@@\.\@:
.ENDM

; Negate 16b A register
.MACRO .NEG_A16
    eor.w #$FFFF
    inc A
.ENDM

; Calculate the absolute value of A, in 8b mode
; ONLY use after an instruction that loads the value into A (checks N flag)
.MACRO .ABS_A8_POSTLOAD
    bpl @@@@@\.\@
    eor.b #$FF
    inc A
@@@@@\.\@:
.ENDM

; Negate 8b register
.MACRO .NEG_A8
    eor.w #$FF
    inc A
.ENDM

; TRUE if x is a power of 2
.FUNCTION IS_POW2(x) !(x & (x - 1))

; returns log₂x
.FUNCTION log2(x) log(x) / log(2.0)

; Cheap method of (A % num), in 8b mode
; only works if 'num' is a power of 2
.MACRO .CheapModA8 ARGS num
    .IF num == 1
    .ELIF num > 0 && num <= (2^7) && IS_POW2(num)
        and.b #(num - 1)
    .ELSE
        .FAIL "CheapModA8: invalid num"
    .ENDIF
.ENDM

; Cheap modulo (A % num), in 16b mode
; only works if 'num' is a power of 2
.MACRO .CheapModA16 ARGS num
    .IF num == 1
    .ELIF num > 1 && num <= (2^15) && IS_POW2(num)
        and.w #(num - 1)
    .ELSE
        .FAIL "CheapModA16: invalid num"
    .ENDIF
.ENDM

; shift accumulator left by 'num' (A << num)
.MACRO .ShiftLeft ARGS num
    .REPT num
        asl
    .ENDR
.ENDM

; shift accumulator right by 'num' (A >> num)
.MACRO .ShiftRight ARGS num
    .REPT num
        lsr
    .ENDR
.ENDM

; Cheap multiplication (A * num)
; only works if 'num' is a power of 2
.MACRO .MultiplyStatic ARGS num
    .IF num == 0
    .ELIF IS_POW2(num)
        .ShiftLeft round(log2(num))
    .ELSE
        .FAIL "MultiplyStatic: invalid num"
    .ENDIF
.ENDM

; Cheap division (A / num)
; only works if 'num' is a power of 2
; Rounds down
.MACRO .DivideStatic ARGS num
    .IF num == 0
    .ELIF IS_POW2(num)
        .ShiftRight round(log2(num))
    .ELSE
        .FAIL "DivideStatic: invalid num"
    .ENDIF
.ENDM

.MACRO .ChangeDataBank ARGS bank
    pea bank + ($0100*(bank))
    plb
    plb
.ENDM

.MACRO .ClearWRam ARGS ADDRL, NBYTES
    rep #$20 ; 16 bit A
    lda #NBYTES
    sta DMA0_SIZE
    lda #loword(vEmptyData__)
    sta DMA0_SRCL
    lda #loword(ADDRL)
    sta WMADDL
    sep #$20 ; 8 bit A
    lda #bankbyte(vEmptyData__)
    sta DMA0_SRCH
    lda #bankbyte(ADDRL)
    sta WMADDH
    ; Absolute address, no increment, 1 byte at a time
    lda #%00001000
    sta DMA0_CTL
    ; Write to WRAM
    lda #$80
    sta DMA0_DEST
    lda #$01
    sta MDMAEN
.ENDM

.MACRO .ClearWRam_ZP ARGS ADDRL, NBYTES
    rep #$20 ; 16 bit A
    lda #NBYTES
    sta.b <DMA0_SIZE
    lda #loword(vEmptyData__)
    sta.b <DMA0_SRCL
    lda #loword(ADDRL)
    sta.l WMADDL
    sep #$20 ; 8 bit A
    lda #bankbyte(vEmptyData__)
    sta.b <DMA0_SRCH
    lda #bankbyte(ADDRL)
    sta.l WMADDH
    ; Absolute address, no increment, 1 byte at a time
    lda #%00001000
    sta.b <DMA0_CTL
    ; Write to WRAM
    lda #$80
    sta.b <DMA0_DEST
    lda #$01
    sta.l MDMAEN
.ENDM

.MACRO .ContextSave_NOA__
    rep #$30 ; 16b AXY
    phx
    phy
    phb
    phd
    lda.l kCurrentPID
    and #$FF
    asl
    tax
    tsc
    sta.l kProcTabStackSave,X
.ENDM

.MACRO .PushStack ARGS newstacksp
    rep #$30 ; 16b aXY
    tsc
    ldx #newstacksp
    txs
    pha
.ENDM

.MACRO .SetStack ARGS newstacksp
    rep #$10
    ldx #newstacksp
    txs
.ENDM

.MACRO .RestoreStack
    rep #$10 ; 16b XY
    plx
    txs
.ENDM

.MACRO .ContextSave__
    rep #$30 ; 16b AXY
    pha
    .ContextSave_NOA__
.ENDM

; Disable IRQ/NMI, pushing value into stack
; A must be 8b
.MACRO .DisableInt__
    lda.l kNMITIMEN
    pha
    lda #1
    sta.l NMITIMEN ; disable NMI and IRQ, while keeping autojoypad on
    sta.l kNMITIMEN
.ENDM

; Restore IRQ/NMI mask stored in stack
; A must be 8b
.MACRO .RestoreInt__
    pla
    sta.l kNMITIMEN
    sta.l NMITIMEN
.ENDM

; use this before using multiply registers
.MACRO .StartMul
    ; just disable interrupts for now
    .DisableInt__
.ENDM

; use this after using multiply registers
.MACRO .EndMul
    .RestoreInt__
.ENDM

.MACRO .DCOLOR_RGB5 ARGS R, G, B
    .dw (B << 10) | (G << 5) | R
.ENDM

.MACRO .BranchIfDigit ARGS target
    cmp #'0'
    bcc @@@@@\.\@
    cmp #'9'+1
    bcc target
@@@@@\.\@:
.ENDM

.MACRO .BranchIfNotDigit ARGS target
    cmp #'0'
    bcc target
    cmp #'9'+1
    bcs target
.ENDM

.MACRO .BranchIfAlpha ARGS target
    cmp #'A'
    bcc @@@@@\.\@end
    cmp #'Z'+1
    bcc target
    cmp #'a'
    bcc @@@@@\.\@end
    cmp #'z'+1
    bcc target
@@@@@\.\@end:
.ENDM

.MACRO .BranchIfNotAlpha ARGS target
    cmp #'A'
    bcc target
    cmp #'Z'+1
    bcc @@@@@\.\@end
    cmp #'a'
    bcc target
    cmp #'z'+1
    bcs target
@@@@@\.\@end:
.ENDM

.MACRO .BranchIfAlnum ARGS target
    cmp #'0'
    bcc @@@@@\.\@end
    cmp #'9'+1
    bcc target
    cmp #'A'
    bcc @@@@@\.\@end
    cmp #'Z'+1
    bcc target
    cmp #'a'
    bcc @@@@@\.\@end
    cmp #'z'+1
    bcc target
@@@@@\.\@end:
.ENDM

.MACRO .BranchIfNotAlnum ARGS target
    cmp #'0'
    bcc target
    cmp #'9'+1
    bcc @@@@@\.\@end
    cmp #'A'
    bcc target
    cmp #'Z'+1
    bcc @@@@@\.\@end
    cmp #'a'
    bcc target
    cmp #'z'+1
    bcs target
@@@@@\.\@end:
.ENDM

.MACRO .CreateReadyProcess ARGS proc, stack, args, n
    sep #$20
    pea args
    pea stack
    .PEAL n
    .PEAL proc
    jsl procCreate
    jsl procResume
    rep #$20 ; 16b A
    pla
    pla
    pla
    pla
    pla
.ENDM

; jump to subroutine absolute long
.MACRO .JSLAL ARGS addr
    phk
    pea @@@@@\.\@ - 1
    jml.w [addr]
    @@@@@\.\@:
.ENDM

.MACRO .PEAB ARGS v
    sep #$20
    lda #v
    pha
.ENDM

.MACRO .PEAL ARGS v
    sep #$20
    lda #bankbyte(v)
    pha
    pea loword(v)
.ENDM

.MACRO .POPN ARGS NUM
    .IF NUM == 0
    .ELIF NUM == 1
        sep #$20
        pla
    .ELIF NUM == 2
        rep #$20
        pla
    .ELIF NUM == 4
        rep #$20
        pla
        pla
    .ELSE
        rep #$20
        tsc
        clc
        adc #NUM
        tcs
    .ENDIF
.ENDM

.MACRO .PrintStringLabel ARGS label
    phb
    .ChangeDataBank bankbyte(label)
    rep #$10
    ldy #loword(label)
    jsl kPutString
    plb
.ENDM

.MACRO .PrintStringLiteral ARGS str
    phb
    phk
    plb
    rep #$10
    ldy #@@@@@\.\@str
    jsl kPutString
    plb
    bra @@@@@\.\@lbl
    @@@@@\.\@str: .db str, "\0"
    @@@@@\.\@lbl:
.ENDM
