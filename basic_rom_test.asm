org $00

ld c,$00

loop:
    ld a,$21
    inc c
    out (c),a
    jr loop

align 8192
