; 1: set A Control register to output mode value
    ld A, 0x0f ; see Z80 peripherals datasheet p209 for what each bit means
    out (2), A
; 2: 0x42 to A Data register
    ld A, 0x00
    out (0), A

    halt

align 256
