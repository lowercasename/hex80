org 0

ld sp,$3fff

main:
    call blink_led
    jp main

blink_led:
    ld a,$42
    out ($00),a
    nop
    nop
    nop
    nop
    ret

align 8192
