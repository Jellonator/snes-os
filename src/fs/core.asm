.include "base.inc"

.BANK $01 SLOT "ROM"
.SECTION "KFSCore" FREE

; Register a filesystem device type
fs_register_device_type:
    rtl


.ENDS