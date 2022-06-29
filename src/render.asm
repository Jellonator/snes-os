.include "base.inc"

.BANK $00 SLOT "ROM"
.SECTION "RenderInterrupt" FREE

KernelVBlank__:
    jml KernelVBlank2__

.ENDS

.BANK $01 SLOT "ROM"
.SECTION "RenderCode" FREE

KernelVBlank2__:
    rti

.ENDS
